import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/model_config.dart';
import '../../services/storage/attachment_storage.dart';
import '../../services/storage/conversation_repository.dart';
import '../../services/storage/model_config_repository.dart';
import '../../services/storage/secure_storage_service.dart';
import '../theme/app_theme.dart';

/// 轻量全局状态（主题、字体缩放、模型、对话）。
/// 不引入第三方状态管理，保持轻量；后续可平滑迁移至 Riverpod。
class AppState {
  AppState._();

  /// 全局单例
  static final AppState instance = AppState._();

  /// 主题模式
  final ValueNotifier<AppThemeMode> themeMode =
      ValueNotifier(AppThemeMode.dark);

  /// 霓虹主题色（自定义主色）
  final ValueNotifier<Color> accentColor =
      ValueNotifier(const Color(0xFF00E5FF));

  /// 全局字体缩放倍数
  final ValueNotifier<double> fontScale = ValueNotifier(1.0);

  /// 对话上下文轮数（<=0 表示不限制）
  final ValueNotifier<int> contextTurns = ValueNotifier(10);

  /// 已配置的模型列表
  final ValueNotifier<List<ModelConfig>> models =
      ValueNotifier(<ModelConfig>[]);

  /// 当前对话使用的模型
  final ValueNotifier<ModelConfig?> currentModel = ValueNotifier(null);

  /// 底部 Tab 当前索引
  final ValueNotifier<int> tabIndex = ValueNotifier(0);

  /// 当前会话
  final ValueNotifier<Conversation?> currentConversation =
      ValueNotifier(null);

  /// 请求打开某个会话（历史页 -> 对话页）
  final ValueNotifier<String?> openConversationId = ValueNotifier(null);

  final ModelConfigRepository repository = ModelConfigRepository();

  final ConversationRepository conversationRepository =
      ConversationRepository();

  /// 启动时加载模型
  Future<void> initModels() async {
    final list = await repository.loadAll();
    models.value = list;
    currentModel.value = _resolveDefault(list);
  }

  /// 启动时恢复最近一次会话
  Future<void> initHistory() async {
    await conversationRepository.deleteEmptyConversations();
    final summaries = await conversationRepository.getConversations();
    if (summaries.isEmpty) return;
    final last = summaries.first;
    final conv = await conversationRepository.getConversation(last.id);
    if (conv == null) return;
    currentConversation.value = conv;
    openConversationId.value = conv.id;
  }

  /// 新建会话（C-01）
  Future<Conversation> newConversation() async {
    final conv = Conversation(
      id: const Uuid().v4(),
      title: '新对话',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await conversationRepository.insertConversation(conv);
    currentConversation.value = conv;
    openConversationId.value = conv.id;
    return conv;
  }

  /// 从历史打开会话
  Future<void> openConversation(String id) async {
    final conv = await conversationRepository.getConversation(id);
    if (conv == null) return;
    currentConversation.value = conv;
    openConversationId.value = conv.id;
    tabIndex.value = 0;
  }

  Future<void> renameConversation(String id, String title) async {
    await conversationRepository.renameConversation(id, title);
    final conv = currentConversation.value;
    if (conv != null && conv.id == id) {
      currentConversation.value = conv.copyWith(title: title);
    }
  }

  /// 删除会话（同时清理其附件文件）
  Future<void> deleteConversation(String id) async {
    final conv = await conversationRepository.getConversation(id);
    if (conv != null) {
      await AttachmentStorage.deleteAll(
        conv.messages.expand((m) => m.attachments.map((a) => a.path)),
      );
    }
    await conversationRepository.deleteConversation(id);
    if (currentConversation.value?.id == id) {
      currentConversation.value = null;
      openConversationId.value = null;
    }
  }

  /// 一键清除全部数据（S-03）：会话、附件、模型配置与 API Key
  Future<void> clearAllData() async {
    await conversationRepository.clearAll();
    await AttachmentStorage.clearAll();
    await repository.clearAll();
    await const SecureStorageService().deleteAllKeys();
    currentConversation.value = null;
    openConversationId.value = null;
    models.value = [];
    currentModel.value = null;
  }

  /// 同步当前会话消息到内存状态
  void syncCurrentMessages(List<Message> messages) {
    final conv = currentConversation.value;
    if (conv == null) return;
    currentConversation.value = conv.copyWith(
      messages: List.of(messages),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> addModel(ModelConfig config) async {
    await repository.save(config);
    final list = [...models.value, config];
    models.value = list;
    if (list.length == 1) {
      await setDefault(config.id);
    }
  }

  Future<void> updateModel(ModelConfig config) async {
    await repository.save(config);
    models.value = [
      for (final m in models.value) m.id == config.id ? config : m,
    ];
    if (currentModel.value?.id == config.id) {
      currentModel.value = config;
    }
  }

  Future<void> removeModel(String id) async {
    await repository.delete(id);
    final list = models.value.where((m) => m.id != id).toList();
    models.value = list;
    if (currentModel.value?.id == id) {
      currentModel.value = _resolveDefault(list);
    }
  }

  Future<void> setDefault(String id) async {
    await repository.setDefault(id);
    models.value = [
      for (final m in models.value) m.copyWith(isDefault: m.id == id),
    ];
    currentModel.value = models.value.where((m) => m.id == id).firstOrNull;
  }

  ModelConfig? _resolveDefault(List<ModelConfig> list) {
    for (final m in list) {
      if (m.isDefault) return m;
    }
    return list.isEmpty ? null : list.first;
  }
}
