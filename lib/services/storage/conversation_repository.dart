import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/attachment.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';

/// 对话仓库（SQLite 本地持久化）。
///
/// conversations 与 messages 两张表，消息外键级联删除。
class ConversationRepository {
  static const _dbName = 'myai_conversations.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        model_config_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        attachments TEXT,
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN attachments TEXT');
    }
  }

  /// 会话列表（按最后更新倒序），可选关键词搜索标题或消息内容
  Future<List<ConversationSummary>> getConversations({String? keyword}) async {
    try {
      final db = await _database;
      var sql = '''
        SELECT c.*,
          (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id) AS message_count,
          (SELECT content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.timestamp DESC LIMIT 1) AS last_message
        FROM conversations c
      ''';
      final args = <Object?>[];
      if (keyword != null && keyword.isNotEmpty) {
        sql += '''
          WHERE c.title LIKE ? OR c.id IN
            (SELECT conversation_id FROM messages WHERE content LIKE ?)
        ''';
        args.addAll(['%$keyword%', '%$keyword%']);
      }
      sql += ' ORDER BY c.updated_at DESC';
      final rows = await db.rawQuery(sql, args);
      return [
        for (final r in rows)
          ConversationSummary(
            id: r['id'] as String,
            title: r['title'] as String,
            updatedAt:
                DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
            messageCount: (r['message_count'] as int?) ?? 0,
            lastMessage: r['last_message'] as String?,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// 加载单个会话（含全部消息）
  Future<Conversation?> getConversation(String id) async {
    try {
      final db = await _database;
      final rows = await db.query(
        'conversations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      final msgRows = await db.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [id],
        orderBy: 'timestamp ASC',
      );
      return Conversation(
        id: id,
        title: r['title'] as String,
        modelConfigId: r['model_config_id'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
        messages: [
          for (final m in msgRows)
            Message(
              id: m['id'] as String,
              role: m['role'] as String,
              content: m['content'] as String,
              timestamp:
                  DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
              attachments: _parseAttachments(m['attachments'] as String?),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> insertConversation(Conversation conv) async {
    try {
      final db = await _database;
      await db.insert('conversations', {
        'id': conv.id,
        'title': conv.title,
        'model_config_id': conv.modelConfigId,
        'created_at': conv.createdAt.millisecondsSinceEpoch,
        'updated_at': conv.updatedAt.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> renameConversation(String id, String title) async {
    try {
      final db = await _database;
      await db.update(
        'conversations',
        {'title': title},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  Future<void> deleteConversation(String id) async {
    try {
      final db = await _database;
      await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  /// 清空所有会话与消息
  Future<void> clearAll() async {
    try {
      final db = await _database;
      await db.delete('messages');
      await db.delete('conversations');
    } catch (_) {}
  }

  Future<void> insertMessage(String conversationId, Message message) async {
    try {
      final db = await _database;
      await db.insert('messages', {
        'id': message.id,
        'conversation_id': conversationId,
        'role': message.role,
        'content': message.content,
        'timestamp':
            (message.timestamp ?? DateTime.now()).millisecondsSinceEpoch,
        'attachments': jsonEncode([
          for (final a in message.attachments) a.toJson(),
        ]),
      });
      await _touch(db, conversationId);
    } catch (_) {}
  }

  Future<void> updateMessageContent(String messageId, String content) async {
    try {
      final db = await _database;
      await db.update(
        'messages',
        {'content': content},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (_) {}
  }

  /// 按 ID 批量删除消息（长按菜单删除/重新生成时清理）
  Future<void> deleteMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await _database;
      await db.delete(
        'messages',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
    } catch (_) {}
  }

  Future<void> deleteAllMessages(String conversationId) async {
    try {
      final db = await _database;
      await db.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      await _touch(db, conversationId);
    } catch (_) {}
  }

  /// 裁剪会话消息数，超过 [maxCount] 时删除最旧消息（防数据库无限膨胀）
  Future<void> trimMessages(String conversationId, int maxCount) async {
    try {
      final db = await _database;
      final count = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM messages WHERE conversation_id = ?',
            [conversationId],
          )) ??
          0;
      if (count <= maxCount) return;
      final excess = count - maxCount;
      await db.rawDelete(
        'DELETE FROM messages WHERE id IN '
        '(SELECT id FROM messages WHERE conversation_id = ? '
        'ORDER BY timestamp ASC LIMIT ?)',
        [conversationId, excess],
      );
    } catch (_) {}
  }

  /// 清理没有任何消息的会话（空会话不产生存储价值）
  Future<void> deleteEmptyConversations() async {
    try {
      final db = await _database;
      await db.rawDelete(
        'DELETE FROM conversations WHERE id NOT IN '
        '(SELECT DISTINCT conversation_id FROM messages)',
      );
    } catch (_) {}
  }

  Future<void> _touch(Database db, String conversationId) async {
    await db.update(
      'conversations',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  List<Attachment> _parseAttachments(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final a in list) Attachment.fromJson(a as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 导出会话为 Markdown 文本；失败返回 null
  Future<String?> exportConversation(String id) async {
    final conv = await getConversation(id);
    if (conv == null) return null;
    final sb = StringBuffer()
      ..writeln('# ${conv.title}')
      ..writeln();
    for (final m in conv.messages) {
      sb
        ..writeln('## ${m.role == 'user' ? '用户' : 'AI'}')
        ..writeln(m.content)
        ..writeln();
    }
    return sb.toString();
  }
}
