import 'package:flutter/material.dart';

import '../../../core/theme/sci_colors.dart';

/// 科幻风格底部导航栏
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, IconData, String)>[
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '对话'),
      (Icons.history_outlined, Icons.history_rounded, '历史'),
      (Icons.smart_toy_outlined, Icons.smart_toy_rounded, '模型'),
      (Icons.settings_outlined, Icons.settings_rounded, '设置'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: SciColors.surfaceOf(context),
        border: Border(
          top: BorderSide(color: SciColors.borderOf(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: SciColors.glow,
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == currentIndex;
            final (icon, activeIcon, label) = items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: selected
                            ? SciColors.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        boxShadow: selected
                            ? SciColors.neonShadow(blur: 10)
                            : null,
                      ),
                      child: Icon(
                        selected ? activeIcon : icon,
                        size: 22,
                        color: selected
                            ? SciColors.primary
                            : SciColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: selected
                            ? SciColors.primary
                            : SciColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
