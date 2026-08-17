import 'package:flutter/material.dart';

import '../../../core/theme/sci_colors.dart';

/// 打开「关于」对话框
Future<void> showAboutInfoDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [SciColors.primary, SciColors.secondary],
              ),
              boxShadow: SciColors.neonShadow(blur: 12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Color(0xFF00222B),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'MyAI Companion',
            style: TextStyle(
              color: SciColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '版本 v1.1.0',
            style: TextStyle(
              color: SciColors.primary,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '科幻风格的本地 AI 对话助手\n支持多模型接入 · 流式输出 · 本地存储',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SciColors.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            '确定',
            style: TextStyle(color: SciColors.primary),
          ),
        ),
      ],
    ),
  );
}
