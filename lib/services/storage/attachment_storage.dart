import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/attachment.dart';

/// 附件存储服务：将附件文件保存到应用私有目录，避免占用系统缓存。
class AttachmentStorage {
  AttachmentStorage._();

  static const _imageExts = <String>{
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
  };

  static bool isImage(String ext) =>
      _imageExts.contains(ext.trim().toLowerCase());

  /// 附件目录（应用文档目录下）
  static Future<Directory> _ensureDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/attachments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 复制一个已选文件到附件目录，返回附件元数据
  static Future<Attachment> copyIn({
    required String sourcePath,
    required String name,
    String? ext,
  }) async {
    final dir = await _ensureDir();
    final safeExt = (ext ?? (name.contains('.') ? name.split('.').last : ''))
        .trim()
        .toLowerCase();
    final id = const Uuid().v4();
    final path = '${dir.path}/$id${safeExt.isEmpty ? '' : '.$safeExt'}';
    await File(sourcePath).copy(path);
    final size = await File(path).length();
    return Attachment(
      id: id,
      name: name,
      type: isImage(safeExt) ? AttachmentType.image : AttachmentType.file,
      size: size,
      path: path,
    );
  }

  /// 删除附件文件（忽略不存在）
  static Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// 批量删除
  static Future<void> deleteAll(Iterable<String> paths) async {
    for (final p in paths) {
      await delete(p);
    }
  }

  /// 清空附件目录（删除会话数据时调用）
  static Future<void> clearAll() async {
    try {
      final dir = await _ensureDir();
      await for (final e in dir.list()) {
        if (e is File) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
