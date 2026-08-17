import 'message.dart';

/// 对话数据模型
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    this.modelConfigId,
    this.tag,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  /// 唯一标识（UUID）
  final String id;

  /// 对话标题（默认取第一条用户消息）
  final String title;

  /// 使用的模型配置 ID
  final String? modelConfigId;

  /// 标签（工作 / 学习 / 闲聊 等）
  final String? tag;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  /// 消息列表
  final List<Message> messages;

  Conversation copyWith({
    String? title,
    String? modelConfigId,
    String? tag,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Message>? messages,
  }) =>
      Conversation(
        id: id,
        title: title ?? this.title,
        modelConfigId: modelConfigId ?? this.modelConfigId,
        tag: tag ?? this.tag,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
      );
}

/// 对话列表摘要（历史列表展示用，不包含消息详情）
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    this.tag,
    required this.updatedAt,
    required this.messageCount,
    this.lastMessage,
  });

  final String id;
  final String title;
  final String? tag;
  final DateTime updatedAt;
  final int messageCount;

  /// 最后一条消息内容（作为摘要展示）
  final String? lastMessage;
}
