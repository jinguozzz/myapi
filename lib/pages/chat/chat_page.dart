import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/sci_colors.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/model_config.dart';
import '../../services/network/chat_service.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input_bar.dart';

/// 对话页面（对接真实大模型 API，SSE 流式输出，会话本地持久化）
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const int _maxMessages = 200;

  final ChatService _chatService = ChatService();
  final Uuid _uuid = const Uuid();
  final List<Message> _messages = [];

  bool _showWelcome = true;
  bool _isGenerating = false;
  String? _pendingAssistantDbId;
  StreamSubscription<String>? _subscription;
  final ScrollController _scrollController = ScrollController();

  bool get _showTyping =>
      _isGenerating && (_messages.isEmpty || _messages.last.role != 'assistant');

  ModelConfig? get _model => AppState.instance.currentModel.value;

  Conversation? get _conversation => AppState.instance.currentConversation.value;

  @override
  void initState() {
    super.initState();
    AppState.instance.currentModel.addListener(_onModelChanged);
    AppState.instance.openConversationId.addListener(_onOpenRequest);
    _restoreConversation();
  }

  @override
  void dispose() {
    AppState.instance.currentModel.removeListener(_onModelChanged);
    AppState.instance.openConversationId.removeListener(_onOpenRequest);
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onModelChanged() {
    if (mounted) setState(() {});
  }

  void _onOpenRequest() {
    final id = AppState.instance.openConversationId.value;
    if (id == null) return;
    final conv = AppState.instance.currentConversation.value;
    if (conv == null || conv.id != id) return;
    if (_isGenerating) _stopGenerating();
    _restoreConversation();
  }

  void _restoreConversation() {
    final conv = AppState.instance.currentConversation.value;
    setState(() {
      _messages
        ..clear()
        ..addAll(conv?.messages ?? []);
      _showWelcome = (conv?.messages.isEmpty ?? true);
    });
    _scrollToBottom();
  }

  Future<void> _handleSend(String text) async {
    final model = _model;
    if (model == null) {
      _toast('请先在「模型」页添加并选择模型');
      return;
    }
    if (text.trim().isEmpty || _isGenerating) return;

    var conv = _conversation;
    if (conv == null) {
      conv = await AppState.instance.newConversation();
      if (!mounted) return;
    }
    final trimmed = text.trim();
    if (conv.title == '新对话') {
      final title =
          trimmed.length > 20 ? '${trimmed.substring(0, 20)}…' : trimmed;
      await AppState.instance.renameConversation(conv.id, title);
    }
    final userMsg = Message(
      id: _uuid.v4(),
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _isGenerating = true;
      _trimMemoryMessages();
    });
    _persistMessage(userMsg);
    _scrollToBottom();
    _startStreaming(model);
  }

  void _startStreaming(ModelConfig model) {
    final requestMessages = _buildRequestMessages();
    try {
      final stream =
          _chatService.streamChat(model: model, messages: requestMessages);
      _subscription = stream.listen(
        _onDelta,
        onError: _onStreamError,
        onDone: _onStreamDone,
      );
    } catch (e) {
      _onStreamError(e);
    }
  }

  void _onDelta(String delta) {
    if (!mounted) return;
    Message? newAssistant;
    setState(() {
      if (_messages.isEmpty || _messages.last.role != 'assistant') {
        newAssistant = Message(
          id: _uuid.v4(),
          role: 'assistant',
          content: delta,
          timestamp: DateTime.now(),
        );
        _messages.add(newAssistant!);
        _pendingAssistantDbId = newAssistant!.id;
      } else {
        final last = _messages.last;
        _messages[_messages.length - 1] =
            last.copyWith(content: last.content + delta);
      }
      _trimMemoryMessages();
    });
    if (newAssistant != null) {
      _persistMessage(newAssistant!);
    }
    _scrollToBottom();
  }

  /// 内存中仅保留最近 [_maxMessages] 条消息
  void _trimMemoryMessages() {
    if (_messages.length > _maxMessages) {
      _messages.removeRange(0, _messages.length - _maxMessages);
    }
  }

  /// 流式一轮结束后裁剪数据库中的历史消息
  void _trimStoredMessages() {
    final conv = _conversation;
    if (conv == null) return;
    AppState.instance.conversationRepository
        .trimMessages(conv.id, _maxMessages);
  }

  void _onStreamDone() {
    if (!mounted) return;
    setState(() => _isGenerating = false);
    _finalizeAssistant();
    AppState.instance.syncCurrentMessages(_messages);
    _trimStoredMessages();
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() {
      _messages.add(Message(
        id: _uuid.v4(),
        role: 'assistant',
        content: '⚠️ ${error.toString()}',
        timestamp: DateTime.now(),
      ));
      _isGenerating = false;
      _trimMemoryMessages();
    });
    _finalizeAssistant();
    _persistLastAssistant();
    AppState.instance.syncCurrentMessages(_messages);
    _trimStoredMessages();
    _scrollToBottom();
  }

  void _stopGenerating() {
    _subscription?.cancel();
    _subscription = null;
    setState(() => _isGenerating = false);
    _finalizeAssistant();
    AppState.instance.syncCurrentMessages(_messages);
    _trimStoredMessages();
  }

  void _finalizeAssistant() {
    final id = _pendingAssistantDbId;
    _pendingAssistantDbId = null;
    if (id == null) return;
    Message? last;
    if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
      last = _messages.last;
    }
    if (last != null && last.id == id) {
      AppState.instance.conversationRepository
          .updateMessageContent(id, last.content);
    }
  }

  void _persistMessage(Message message) {
    final conv = _conversation;
    if (conv == null) return;
    AppState.instance.conversationRepository.insertMessage(conv.id, message);
  }

  void _persistLastAssistant() {
    final conv = _conversation;
    if (conv == null) return;
    if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
      AppState.instance.conversationRepository
          .insertMessage(conv.id, _messages.last);
    }
  }

  /// 按上下文轮数截断，构建发送给模型的请求消息列表
  List<Message> _buildRequestMessages() {
    final msgs = List<Message>.from(_messages);
    final turns = AppState.instance.contextTurns.value;
    if (turns <= 0) return msgs;
    while (msgs.where((m) => m.role == 'user').length > turns) {
      msgs.removeAt(0);
    }
    return msgs;
  }

  /// 新建对话（C-01）
  Future<void> _newConversation() async {
    if (_isGenerating) _stopGenerating();
    final hasUser = _messages.any((m) => m.role == 'user');
    if (!hasUser) {
      await AppState.instance.newConversation();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建对话'),
        content: const Text(
          '将新建一个会话，当前会话将保留在「历史」中。',
          style: TextStyle(color: SciColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '取消',
              style: TextStyle(color: SciColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('新建', style: TextStyle(color: SciColors.primary)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AppState.instance.newConversation();
    }
  }

  /// 清空当前会话消息（保留会话记录）
  Future<void> _clearConversation() async {
    _stopGenerating();
    final conv = _conversation;
    if (conv == null) return;
    await AppState.instance.conversationRepository
        .deleteAllMessages(conv.id);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _showWelcome = true;
    });
  }

  /// 重新生成最后一条 AI 回复（C-07）
  void _regenerate() {
    final model = _model;
    if (model == null) {
      _toast('请先在「模型」页添加并选择模型');
      return;
    }
    if (_isGenerating) {
      _toast('正在生成中，请稍候');
      return;
    }
    if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
      setState(() => _messages.removeLast());
    }
    if (_messages.isEmpty || _messages.last.role != 'user') {
      _toast('没有可重新生成的消息');
      return;
    }
    setState(() => _isGenerating = true);
    _scrollToBottom();
    _startStreaming(model);
  }

  /// 一键复制最近一条 AI 回复
  void _copyLastAiReply() {
    String content = '';
    for (final m in _messages.reversed) {
      if (m.role == 'assistant') {
        content = m.content;
        break;
      }
    }
    if (content.isEmpty) {
      _toast('暂无 AI 回复可复制');
      return;
    }
    Clipboard.setData(ClipboardData(text: content));
    _toast('已复制 AI 回复');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showWelcome = _showWelcome && _messages.isEmpty;
    final itemCount =
        _messages.length + (_showTyping ? 1 : 0) + (showWelcome ? 1 : 0);
    return Scaffold(
      backgroundColor: SciColors.backgroundOf(context),
      appBar: ChatAppBar(
        title: '深空对话',
        onNewConversation: _newConversation,
        onRegenerate: _regenerate,
        onClearConversation: _clearConversation,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (showWelcome) {
                  if (index == 0) {
                    return const MessageBubble(
                      role: 'assistant',
                      content: '你好，我是 MyAI Companion。\n\n在「模型」页添加并选择模型后，即可开始真实 AI 对话。',
                    );
                  }
                  index -= 1;
                }
                if (index == _messages.length) {
                  return const MessageBubble(
                    role: 'assistant',
                    content: '',
                    isTyping: true,
                  );
                }
                final msg = _messages[index];
                return MessageBubble(
                  role: msg.role,
                  content: msg.content,
                  isStreaming: msg.role == 'assistant' &&
                      index == _messages.length - 1 &&
                      _isGenerating,
                );
              },
            ),
          ),
          MessageInputBar(
            isGenerating: _isGenerating,
            onSend: _handleSend,
            onStop: _stopGenerating,
            onCopy: _copyLastAiReply,
          ),
        ],
      ),
    );
  }
}
