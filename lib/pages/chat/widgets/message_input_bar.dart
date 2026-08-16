import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/sci_colors.dart';

/// 底部输入栏（输入框 + 复制 / 语音 / 发送 / 停止按钮）
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.onCopy,
    required this.isGenerating,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  /// 一键复制（由页面层决定复制内容，通常为最近一条 AI 回复）
  final VoidCallback onCopy;
  final bool isGenerating;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  bool _isListening = false;
  Timer? _voiceTimer;

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
    _voiceTimer?.cancel();
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

  void _toggleVoice() {
    if (_isListening) {
      _stopVoice(commit: true);
    } else {
      _startVoice();
    }
  }

  void _startVoice() {
    setState(() {
      _isListening = true;
      _pulseController.repeat(reverse: true);
    });
    _voiceTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _stopVoice(commit: true);
    });
  }

  void _stopVoice({required bool commit}) {
    _voiceTimer?.cancel();
    _pulseController.stop();
    _pulseController.value = 0;
    if (commit) {
      final mock = '语音识别演示：你好，我是 MyAI。';
      _controller.text =
          _controller.text.trim().isEmpty ? mock : '${_controller.text.trim()} $mock';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
    setState(() => _isListening = false);
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
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('附件功能开发中')),
                );
              },
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
                      ? '正在聆听…（再次点击结束）'
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

  Widget _iconButton(IconData icon, {required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: SciColors.textSecondaryOf(context),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _micButton() {
    return Tooltip(
      message: _isListening ? '结束语音输入' : '语音输入',
      child: InkWell(
        onTap: _toggleVoice,
        borderRadius: BorderRadius.circular(10),
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
              : const LinearGradient(
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
