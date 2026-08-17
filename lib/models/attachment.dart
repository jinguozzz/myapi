/// 附件类型
enum AttachmentType { image, file }

/// 消息附件（图片 / 文件）
///
/// 文件本体保存在应用私有目录下，模型中只存元数据与绝对路径。
class Attachment {
  const Attachment({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.path,
  });

  final String id;
  final String name;
  final AttachmentType type;

  /// 文件大小（字节）
  final int size;

  /// 存储在本地的绝对路径
  final String path;

  Attachment copyWith({String? name, AttachmentType? type, int? size, String? path}) =>
      Attachment(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        size: size ?? this.size,
        path: path ?? this.path,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'size': size,
        'path': path,
      };

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] == 'image'
            ? AttachmentType.image
            : AttachmentType.file,
        size: (json['size'] as num?)?.toInt() ?? 0,
        path: json['path'] as String,
      );

  /// 人类可读的文件大小
  String get displaySize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
