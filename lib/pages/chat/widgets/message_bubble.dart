import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/sci_colors.dart';
import 'markdown_view.dart';

/// 消息气泡（用户 / AI），支持流式与输入中状态
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.isTyping = false,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final bool isStreaming;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: isUser
          ? _buildUserBubble()
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AiAvatar(),
                const SizedBox(width: 8),
                Expanded(child: _buildAssistantBubble(context)),
              ],
            ),
    );
  }

  Widget _buildUserBubble() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2A3A), Color(0xFF123047)],
        ),
        borderRadius:
            BorderRadius.circular(14).copyWith(bottomRight: Radius.zero),
        border: Border.all(
          color: SciColors.primaryDim.withValues(alpha: 0.5),
        ),
        boxShadow: SciColors.neonShadow(blur: 10),
      ),
      child: Text(
        content,
        style: const TextStyle(
          color: SciColors.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SciColors.surfaceOf(context),
        borderRadius:
            BorderRadius.circular(14).copyWith(bottomLeft: Radius.zero),
        border: Border.all(color: SciColors.borderOf(context)),
      ),
      child: isTyping
          ? const _TypingIndicator()
          : MarkdownView(data: content, streaming: isStreaming),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SciColors.primary, SciColors.secondary],
        ),
        boxShadow: SciColors.neonShadow(blur: 12),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 16,
        color: Color(0xFF00222B),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final phase = (_controller.value + i / 3) % 1;
            final scale = 0.6 + 0.4 * math.sin(phase * math.pi);
            return Container(
              width: 6,
              height: 6 * scale,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: SciColors.primary.withValues(alpha: 0.4 + 0.6 * scale),
                borderRadius: BorderRadius.circular(3),
                boxShadow: SciColors.neonShadow(blur: 6),
              ),
            );
          },
        );
      }),
    );
  }
}
