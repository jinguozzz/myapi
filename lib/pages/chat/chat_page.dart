import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/sci_colors.dart';
import '../../models/attachment.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/model_config.dart';
import '../../models/prompt_template.dart';
import '../../services/network/chat_service.dart';
import '../../services/network/weather_service.dart';
import '../../services/network/web_search_service.dart';
import '../../services/storage/attachment_storage.dart';
import '../../services/tools/smart_tool.dart';
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
  final WebSearchService _webSearch = WebSearchService();
  final WeatherService _weather = WeatherService();
  final SmartTool _smartTool = SmartTool();
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterTts _tts = FlutterTts();
  final Uuid _uuid = const Uuid();
  final GlobalKey<MessageInputBarState> _inputKey =
      GlobalKey<MessageInputBarState>();
  final List<Message> _messages = [];
  final List<Attachment> _pendingAttachments = [];

  /// 正在朗读的消息 ID
  String? _speakingId;

  /// 是否开启联网搜索
  bool _webSearchEnabled = false;

  /// 是否开启翻译模式
  bool _translateMode = false;

  bool _showWelcome = true;
  bool _isGenerating = false;
  String? _pendingAssistantDbId;
  StreamSubscription<String>? _subscription;
  final ScrollController _scrollController = ScrollController();

  bool get _showTyping =>
      _isGenerating && (_messages.isEmpty || _messages.last.role != 'assistant');

  bool get _lastIsError =>
      !_isGenerating &&
      _messages.isNotEmpty &&
      _messages.last.role == 'assistant' &&
      _messages.last.content.startsWith('⚠️');

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
    _tts.stop();
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
      attachments: List.of(_pendingAttachments),
    );
    setState(() {
      _messages.add(userMsg);
      _isGenerating = true;
      _pendingAttachments.clear();
      _trimMemoryMessages();
    });
    _persistMessage(userMsg);
    _scrollToBottom();

    // 1) 本地工具（计算 / 单位换算）
    List<Message> requestMessages = _buildRequestMessages();
    final toolResult = _smartTool.run(trimmed);
    if (toolResult != null) {
      requestMessages = [
        Message(
          id: _uuid.v4(),
          role: 'system',
          content: '本地工具结果：$toolResult\n请直接、简洁地告诉用户这个结果。',
          timestamp: DateTime.now(),
        ),
        ...requestMessages,
      ];
    } else {
      // 2) 联网搜索 + 实时天气
      if (_webSearchEnabled) {
        _toast('正在联网搜索…');
        final context = await _fetchSearchContext(trimmed);
        if (context != null) {
          requestMessages = [
            Message(
              id: _uuid.v4(),
              role: 'system',
              content: context,
              timestamp: DateTime.now(),
            ),
            ...requestMessages,
          ];
          _toast('已获取联网结果，正在回答');
        } else {
          _toast('联网搜索未获取到结果，已直接提问');
        }
      }
    }

    // 3) 翻译模式
    if (_translateMode) {
      requestMessages = [
        Message(
          id: _uuid.v4(),
          role: 'system',
          content: '你是翻译助手：把用户最新一条消息翻译为另一种语言'
              '（中文翻译成英文；英文或其他语言翻译成中文）。'
              '只输出译文，不要输出多余内容。',
          timestamp: DateTime.now(),
        ),
        ...requestMessages,
      ];
    }
    _startStreaming(model, messages: requestMessages);
  }

  /// 抓取搜索结果并组装为系统上下文（含实时天气，若问题涉及天气）
  Future<String?> _fetchSearchContext(String query) async {
    final parts = <String>[];

    // 1. 天气类问题：实时天气
    final weather = await _tryWeather(query);
    if (weather != null) parts.add(weather);

    // 2. 通用联网搜索
    try {
      final results = await _webSearch.search(query);
      if (results.isNotEmpty) {
        final sb = StringBuffer()
          ..writeln('以下是联网搜索到的资料：')
          ..writeln();
        for (var i = 0; i < results.length; i++) {
          final r = results[i];
          sb
            ..writeln('[${i + 1}] ${r.title}')
            ..writeln(r.snippet.isEmpty ? '（无摘要）' : r.snippet)
            ..writeln('来源：${r.url}')
            ..writeln();
        }
        parts.add(sb.toString());
      }
    } catch (_) {}

    return parts.isEmpty ? null : parts.join('\n\n');
  }

  /// 天气类问题：识别城市并查询实时天气
  Future<String?> _tryWeather(String query) async {
    final isWeather = RegExp('天气|气温|温度|下雨|下雪|降雨|湿度|台风')
        .hasMatch(query);
    if (!isWeather) return null;
    final city = _weather.extractCity(query);
    if (city == null) return null;
    try {
      final info = await _weather.fetch(city);
      if (info == null) return null;
      return '用户询问「$city」的实时天气。\n'
          '实时天气数据（来自 wttr.in）：\n$info\n'
          '请基于以上实时天气数据回答用户问题。';
    } catch (_) {
      return null;
    }
  }

  /// 附件入口：拍照 / 选图片 / 选文件
  Future<void> _onAttach() async {
    final action = await showModalBottomSheet<_AttachAction>(
      context: context,
      backgroundColor: SciColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '添加附件',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: SciColors.primary, size: 20),
              title: const Text('拍照上传',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              subtitle: const Text('调用系统相机拍摄后上传',
                  style: TextStyle(color: SciColors.textSecondary, fontSize: 11)),
              onTap: () => Navigator.of(ctx).pop(_AttachAction.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: SciColors.primary, size: 20),
              title: const Text('从相册选择图片',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              subtitle: const Text('图片将以视觉内容随消息发送',
                  style: TextStyle(color: SciColors.textSecondary, fontSize: 11)),
              onTap: () => Navigator.of(ctx).pop(_AttachAction.image),
            ),
            ListTile(
              leading: Icon(Icons.folder_open_rounded,
                  color: SciColors.primary, size: 20),
              title: const Text('选择文件',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              subtitle: const Text('文件仅本地展示，不随消息上传',
                  style: TextStyle(color: SciColors.textSecondary, fontSize: 11)),
              onTap: () => Navigator.of(ctx).pop(_AttachAction.file),
            ),
            ListTile(
              leading: Icon(Icons.document_scanner_outlined,
                  color: SciColors.primary, size: 20),
              title: const Text('OCR 识别文字',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              subtitle: const Text('识别图片/截图中的文字并填入输入框',
                  style: TextStyle(color: SciColors.textSecondary, fontSize: 11)),
              onTap: () => Navigator.of(ctx).pop(_AttachAction.ocr),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _AttachAction.camera:
        await _takePhoto();
      case _AttachAction.image:
        await _pickFiles(FileType.image);
      case _AttachAction.file:
        await _pickFiles(FileType.any);
      case _AttachAction.ocr:
        await _ocrImage();
    }
  }

  /// OCR 识别图片文字（离线，ML Kit 中文模型）
  Future<void> _ocrImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path == null) return;
      _toast('正在识别文字…');
      final recognizer =
          TextRecognizer(script: TextRecognitionScript.chinese);
      try {
        final result = await recognizer
            .processImage(InputImage.fromFilePath(path));
        final text = result.text.trim();
        if (text.isEmpty) {
          _toast('未识别到文字');
          return;
        }
        _inputKey.currentState?.setText(text);
        _toast('已提取 ${text.length} 字，可编辑后提问');
      } finally {
        recognizer.close();
      }
    } catch (e) {
      if (mounted) _toast('OCR 识别失败：$e');
    }
  }

  /// 快捷指令：一键发送
  Future<void> _showQuickCommands() async {
    final command = await showModalBottomSheet<QuickCommand>(
      context: context,
      backgroundColor: SciColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '快捷指令',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final c in quickCommands)
              ListTile(
                leading: Icon(Icons.bolt_rounded,
                    color: SciColors.primary, size: 18),
                title: Text(
                  c.label,
                  style: const TextStyle(
                      color: SciColors.textPrimary, fontSize: 14),
                ),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (command == null || !mounted) return;
    await _handleSend(command.content);
  }

  /// 拍照上传（调用系统相机）
  Future<void> _takePhoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      final ext = picked.path.contains('.')
          ? picked.path.split('.').last
          : 'jpg';
      final attachment = await AttachmentStorage.copyIn(
        sourcePath: picked.path,
        name: 'photo.$ext',
        ext: ext,
      );
      if (!mounted) return;
      setState(() => _pendingAttachments.add(attachment));
      _warnIfNotVision([attachment]);
    } catch (e) {
      if (mounted) _toast('拍照失败：$e');
    }
  }

  Future<void> _pickFiles(FileType type) async {
    try {
      final files = await FilePicker.pickFiles(type: type);
      if (files.isEmpty) return;
      final picked = <Attachment>[];
      for (final f in files) {
        final path = f.path;
        if (path == null) continue;
        try {
          picked.add(await AttachmentStorage.copyIn(
            sourcePath: path,
            name: f.name,
          ));
        } catch (_) {}
      }
      if (picked.isEmpty) return;
      if (!mounted) return;
      setState(() => _pendingAttachments.addAll(picked));
      _warnIfNotVision(picked);
    } catch (e) {
      if (mounted) _toast('选择文件失败：$e');
    }
  }

  /// 当前模型不支持视觉时提示图片仅本地展示
  void _warnIfNotVision(List<Attachment> attachments) {
    if (!attachments.any((a) => a.type == AttachmentType.image)) return;
    if (_model?.supportsVision ?? false) return;
    _toast('当前模型不支持图片识别，图片将仅本地展示，不会发送给模型');
  }

  void _removePendingAttachment(Attachment a) {
    setState(() => _pendingAttachments.remove(a));
    AttachmentStorage.delete(a.path);
  }

  void _startStreaming(ModelConfig model, {List<Message>? messages}) {
    final requestMessages = messages ?? _buildRequestMessages();
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
            child: Text('新建', style: TextStyle(color: SciColors.primary)),
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
    final paths = _messages
        .expand((m) => m.attachments.map((a) => a.path));
    await AttachmentStorage.deleteAll(paths);
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

  /// 长按消息操作菜单：复制 / 重新生成 / 删除
  void _showMessageActions(Message msg) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SciColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '消息操作',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.content_copy_rounded,
                  color: SciColors.primary, size: 20),
              title: const Text('复制内容',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: msg.content));
                _toast('已复制');
              },
            ),
            if (msg.role == 'assistant')
              ListTile(
                leading: Icon(
                    _speakingId == msg.id
                        ? Icons.stop_rounded
                        : Icons.volume_up_outlined,
                    color: SciColors.primary,
                    size: 20),
                title: Text(
                  _speakingId == msg.id ? '停止朗读' : '朗读回复',
                  style: const TextStyle(
                      color: SciColors.textPrimary, fontSize: 14),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _toggleSpeak(msg);
                },
              ),
            if (msg.role == 'user')
              ListTile(
                leading: Icon(Icons.edit_outlined,
                    color: SciColors.primary, size: 20),
                title: const Text('编辑消息',
                    style:
                        TextStyle(color: SciColors.textPrimary, fontSize: 14)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _editMessage(msg);
                },
              ),
            if (msg.role == 'assistant')
              ListTile(
                leading: Icon(Icons.refresh_rounded,
                    color: SciColors.primary, size: 20),
                title: const Text('从此处重新生成',
                    style:
                        TextStyle(color: SciColors.textPrimary, fontSize: 14)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _regenerateFrom(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: SciColors.danger, size: 20),
              title: const Text('删除消息',
                  style: TextStyle(color: SciColors.danger, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteMessage(msg);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 删除单条消息（含附件文件）
  Future<void> _deleteMessage(Message msg) async {
    final conv = _conversation;
    setState(() => _messages.remove(msg));
    if (conv != null) {
      await AppState.instance.conversationRepository
          .deleteMessagesByIds([msg.id]);
    }
    await AttachmentStorage.deleteAll(msg.attachments.map((a) => a.path));
    AppState.instance.syncCurrentMessages(_messages);
  }

  /// 编辑用户消息内容
  Future<void> _editMessage(Message msg) async {
    final ctrl = TextEditingController(text: msg.content);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑消息'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          style: const TextStyle(color: SciColors.textPrimary),
          decoration: const InputDecoration(hintText: '修改内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: SciColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text('保存', style: TextStyle(color: SciColors.primary)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final text = result?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    final updated = msg.copyWith(content: text);
    setState(() {
      final i = _messages.indexOf(msg);
      if (i >= 0) _messages[i] = updated;
    });
    await AppState.instance.conversationRepository
        .updateMessageContent(msg.id, text);
    AppState.instance.syncCurrentMessages(_messages);
    _toast('已更新消息');
  }

  /// 朗读 / 停止朗读 AI 回复
  Future<void> _toggleSpeak(Message msg) async {
    try {
      if (_speakingId == msg.id) {
        await _tts.stop();
        _speakingId = null;
        return;
      }
      await _tts.stop();
      // Android 检查是否有语音合成引擎
      final engines = (await _tts.getEngines) ?? <dynamic>[];
      if (engines.isEmpty) {
        _toast('设备未安装语音合成引擎（如 Google TTS / 讯飞语音），无法朗读');
        return;
      }
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      final result = await _tts.speak(msg.content);
      if (result == 1) {
        _speakingId = msg.id;
      } else {
        _toast('朗读失败，请检查语音合成引擎设置');
      }
    } catch (e) {
      _toast('朗读失败：$e');
    }
  }

  /// 应用 Prompt 模板：注入系统提示词
  Future<void> _applyTemplate() async {
    final template = await showModalBottomSheet<PromptTemplate>(
      context: context,
      backgroundColor: SciColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final categories = <String>[];
        for (final t in promptTemplates) {
          if (!categories.contains(t.category)) categories.add(t.category);
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Prompt 模板',
                  style: TextStyle(
                    color: SciColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              for (final category in categories) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: SciColors.primary,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                for (final t in promptTemplates
                    .where((t) => t.category == category))
                  ListTile(
                    leading: Icon(Icons.auto_awesome_rounded,
                        color: SciColors.primary, size: 18),
                    title: Text(
                      t.title,
                      style: const TextStyle(
                          color: SciColors.textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      t.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: SciColors.textSecondary, fontSize: 11),
                    ),
                    onTap: () => Navigator.of(ctx).pop(t),
                  ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (template == null || !mounted) return;
    var conv = _conversation;
    if (conv == null) {
      conv = await AppState.instance.newConversation();
      if (!mounted) return;
    }
    final sysMsg = Message(
      id: _uuid.v4(),
      role: 'system',
      content: template.prompt,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(sysMsg);
      _trimMemoryMessages();
    });
    _persistMessage(sysMsg);
    AppState.instance.syncCurrentMessages(_messages);
    _scrollToBottom();
    _toast('已应用模板：${template.title}');
  }

  /// 从指定消息处截断并重新生成
  void _regenerateFrom(Message msg) {
    final i = _messages.indexOf(msg);
    if (i < 0) return;
    if (i + 1 < _messages.length) {
      final removed = _messages.sublist(i + 1);
      setState(() => _messages.removeRange(i + 1, _messages.length));
      final conv = _conversation;
      if (conv != null) {
        AppState.instance.conversationRepository
            .deleteMessagesByIds(removed.map((m) => m.id).toList());
      }
      AttachmentStorage.deleteAll(
        removed.expand((m) => m.attachments.map((a) => a.path)),
      );
    }
    _regenerate();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        final position = _scrollController.position;
        if (!position.hasContentDimensions) return;
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } catch (_) {}
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
        onApplyTemplate: _applyTemplate,
        onQuickCommand: _showQuickCommands,
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
                if (msg.role == 'system') {
                  return _SystemBanner(
                    text: msg.content,
                    onRemove: () => _deleteMessage(msg),
                  );
                }
                return MessageBubble(
                  role: msg.role,
                  content: msg.content,
                  attachments: msg.attachments,
                  isStreaming: msg.role == 'assistant' &&
                      index == _messages.length - 1 &&
                      _isGenerating,
                  onLongPress: () => _showMessageActions(msg),
                );
              },
            ),
          ),
          if (_pendingAttachments.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _pendingAttachments)
                    _PendingChip(
                      attachment: a,
                      onRemove: () => _removePendingAttachment(a),
                    ),
                ],
              ),
            ),
          if (_lastIsError)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: _regenerate,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: SciColors.primary,
                ),
                label: Text(
                  '重试',
                  style: TextStyle(color: SciColors.primary, fontSize: 13),
                ),
              ),
            ),
          MessageInputBar(
            key: _inputKey,
            isGenerating: _isGenerating,
            webSearchEnabled: _webSearchEnabled,
            translateMode: _translateMode,
            onSend: _handleSend,
            onStop: _stopGenerating,
            onCopy: _copyLastAiReply,
            onAttach: _onAttach,
            onToggleWebSearch: () =>
                setState(() => _webSearchEnabled = !_webSearchEnabled),
            onToggleTranslate: () =>
                setState(() => _translateMode = !_translateMode),
          ),
        ],
      ),
    );
  }
}

/// 附件操作类型
enum _AttachAction { camera, image, file, ocr }

/// 待发送附件芯片
class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.attachment, required this.onRemove});

  final Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.type == AttachmentType.image;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      decoration: BoxDecoration(
        color: SciColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SciColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(attachment.path),
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 34,
                  height: 34,
                  color: SciColors.surfaceLight,
                  child: const Icon(Icons.image_outlined,
                      size: 18, color: SciColors.textSecondary),
                ),
              ),
            )
          else
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SciColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.insert_drive_file_outlined,
                  size: 18, color: SciColors.primary),
            ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: SciColors.textPrimaryOf(context),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: SciColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 系统提示横幅（Prompt 模板）
class _SystemBanner extends StatelessWidget {
  const _SystemBanner({required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: SciColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SciColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: SciColors.primary, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SciColors.textPrimaryOf(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    color: SciColors.textSecondaryOf(context), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
