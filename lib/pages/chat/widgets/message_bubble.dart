import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/sci_colors.dart';
import '../../../models/attachment.dart';
import 'markdown_view.dart';

/// 消息气泡（用户 / AI），支持流式、输入中状态与附件展示
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.attachments = const [],
    this.isStreaming = false,
    this.isTyping = false,
    this.onLongPress,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final List<Attachment> attachments;
  final bool isStreaming;
  final bool isTyping;

  /// 长按消息回调（用于消息操作菜单）
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
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
      ),
    );
  }

  Widget _buildUserBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachments.isNotEmpty) ...[
            _AttachmentGrid(attachments: attachments),
            if (content.trim().isNotEmpty) const SizedBox(height: 6),
          ],
          if (content.trim().isNotEmpty)
            Text(
              content,
              style: const TextStyle(
                color: SciColors.textPrimary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
        ],
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
        gradient: LinearGradient(
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

/// 附件展示：图片以网格缩略图，文件以芯片形式
class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({required this.attachments});

  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) {
    final images = attachments
        .where((a) => a.type == AttachmentType.image)
        .toList(growable: false);
    final files = attachments
        .where((a) => a.type == AttachmentType.file)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (images.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final img in images)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(img.path),
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(img),
                  ),
                ),
            ],
          ),
        ],
        if (files.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 6),
          for (final f in files)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: SciColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SciColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    color: SciColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SciColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    f.displaySize,
                    style: const TextStyle(
                      color: SciColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _fallback(Attachment a) {
    return Container(
      width: 110,
      height: 110,
      color: SciColors.surfaceLight,
      child: Icon(Icons.broken_image_outlined, color: SciColors.textSecondary),
    );
  }
}
