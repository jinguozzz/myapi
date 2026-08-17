import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/sci_colors.dart';

/// 底部输入栏（输入框 + 复制 / 语音 / 发送 / 停止按钮）
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.onCopy,
    required this.onAttach,
    required this.onToggleWebSearch,
    required this.webSearchEnabled,
    required this.isGenerating,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  /// 一键复制（由页面层决定复制内容，通常为最近一条 AI 回复）
  final VoidCallback onCopy;

  /// 打开附件选择
  final VoidCallback onAttach;

  /// 切换联网搜索
  final VoidCallback onToggleWebSearch;

  /// 是否已开启联网搜索
  final bool webSearchEnabled;
  final bool isGenerating;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _hasText = false;
  bool _isListening = false;
  String _lastRecognized = '';

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      }
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isGenerating) {
      widget.onStop();
      return;
    }
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }

  Future<void> _startVoice() async {
    try {
      _lastRecognized = '';
      // Android 需要运行时申请麦克风权限
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能使用语音输入')),
          );
        }
        return;
      }
      final available = await _speech.initialize(
        onError: (_) => _onVoiceEnd(),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_isListening) _onVoiceEnd();
          }
        },
      );
      if (!available || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('语音识别不可用，请确认系统已安装语音识别服务'),
            ),
          );
        }
        return;
      }
      setState(() {
        _isListening = true;
        _pulseController.repeat(reverse: true);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在聆听，松开发送…')),
        );
      }
      final locale = (await _speech.systemLocale())?.localeId;
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final text = result.recognizedWords;
          _lastRecognized = text;
          _controller.text = text;
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 3),
          localeId: locale,
          onDevice: false,
        ),
      );
    } on PlatformException catch (e) {
      if (mounted) {
        _onVoiceEnd();
        final msg = e.code == 'recognizerNotAvailable'
            ? '设备未检测到语音识别服务。\n请安装/启用 Google 应用后重试，或使用输入法自带的语音输入。'
            : '语音输入失败：$e';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        _onVoiceEnd();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('语音输入失败：$e')));
      }
    }
  }

  /// 松开发送 / 取消不发送（保留在输入框）
  Future<void> _finishVoice({required bool send}) async {
    try {
      await _speech.stop();
    } catch (_) {}
    _onVoiceEnd();
    final text = _lastRecognized.trim();
    _lastRecognized = '';
    if (text.isEmpty || !mounted) return;
    if (send) {
      _controller.clear();
      widget.onSend(text);
    } else {
      _controller.text = text;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  void _onVoiceEnd() {
    _pulseController.stop();
    _pulseController.value = 0;
    if (mounted) setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SciColors.surfaceOf(context),
        border: Border(
          top: BorderSide(color: SciColors.borderOf(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: SciColors.glow,
            blurRadius: 16,
            spreadRadius: -8,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _iconButton(
              Icons.attach_file_rounded,
              tooltip: '附件',
              onTap: widget.onAttach,
            ),
            const SizedBox(width: 4),
            _iconButton(
              Icons.content_copy_rounded,
              tooltip: '复制 AI 回复',
              onTap: widget.onCopy,
            ),
            const SizedBox(width: 4),
            _micButton(),
            const SizedBox(width: 4),
            _iconButton(
              Icons.public_rounded,
              tooltip: widget.webSearchEnabled ? '联网搜索：开' : '联网搜索：关',
              active: widget.webSearchEnabled,
              onTap: widget.onToggleWebSearch,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(
                  color: SciColors.textPrimaryOf(context),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? '正在聆听… 松开发送'
                      : '输入消息，Enter 发送…',
                  hintStyle: TextStyle(
                    color: _isListening
                        ? SciColors.danger
                        : SciColors.textSecondaryOf(context),
                  ),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 6),
            _sendButton(),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(
    IconData icon, {
    required VoidCallback onTap,
    String? tooltip,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: active
                ? SciColors.primary
                : SciColors.textSecondaryOf(context),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _micButton() {
    return Tooltip(
      message: '按住说话，松开发送',
      child: GestureDetector(
        onLongPressStart: (_) => _startVoice(),
        onLongPressEnd: (_) => _finishVoice(send: true),
        onLongPressCancel: () => _finishVoice(send: false),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = _isListening ? 1.0 + 0.25 * _pulseController.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: Icon(
                  _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  color: _isListening
                      ? SciColors.danger
                      : SciColors.textSecondaryOf(context),
                  size: 22,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sendButton() {
    final isGen = widget.isGenerating;
    return GestureDetector(
      onTap: _submit,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isGen
              ? const LinearGradient(
                  colors: [SciColors.danger, Color(0xFF8A2E44)],
                )
              : LinearGradient(
                  colors: [SciColors.primary, SciColors.secondary],
                ),
          boxShadow: isGen
              ? [
                  BoxShadow(
                    color: SciColors.danger.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ]
              : SciColors.neonShadow(blur: 14),
        ),
        child: Icon(
          isGen ? Icons.stop_rounded : Icons.arrow_upward_rounded,
          size: 22,
          color: const Color(0xFF00222B),
        ),
      ),
    );
  }
}
