import 'attachment.dart';

/// 消息数据模型
class Message {
  const Message({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.attachments = const [],
  });

  /// 唯一标识（UUID）
  final String id;

  /// 'user' | 'assistant' | 'system'
  final String role;

  /// 消息内容
  final String content;

  /// 时间戳
  final DateTime? timestamp;

  /// 附件（图片 / 文件）
  final List<Attachment> attachments;

  Message copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    List<Attachment>? attachments,
  }) =>
      Message(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
        attachments: attachments ?? this.attachments,
      );

  /// OpenAI 兼容的纯文本格式（含附件时由 ChatService 组装视觉内容）
  Map<String, dynamic> toApiJson() => {'role': role, 'content': content};

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp?.millisecondsSinceEpoch,
        'attachments': [for (final a in attachments) a.toJson()],
      };

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List<dynamic>? ?? [];
    return Message(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      attachments: [
        for (final a in rawAttachments)
          Attachment.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}
