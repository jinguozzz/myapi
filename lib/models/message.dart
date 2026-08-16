/// 消息数据模型
class Message {
  const Message({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
  });

  /// 唯一标识（UUID）
  final String id;

  /// 'user' | 'assistant' | 'system'
  final String role;

  /// 消息内容
  final String content;

  /// 时间戳
  final DateTime? timestamp;

  Message copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
  }) =>
      Message(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
      );

  /// OpenAI 兼容的 API 请求格式
  Map<String, dynamic> toApiJson() => {'role': role, 'content': content};
}
