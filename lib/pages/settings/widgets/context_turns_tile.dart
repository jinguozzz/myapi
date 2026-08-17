import 'package:flutter/material.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/sci_colors.dart';

/// 对话上下文轮数设置项
class ContextTurnsTile extends StatelessWidget {
  const ContextTurnsTile({super.key});

  String _label(int turns) => turns <= 0 ? '不限制' : '最近 $turns 轮';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppState.instance.contextTurns,
      builder: (context, turns, _) {
        return InkWell(
          onTap: () => _showPicker(context, turns),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: SciColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SciColors.borderOf(context)),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: SciColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '上下文轮数',
                    style: TextStyle(
                      color: SciColors.textPrimaryOf(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  _label(turns),
                  style: TextStyle(
                    color: SciColors.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: SciColors.textSecondaryOf(context),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPicker(BuildContext context, int current) {
    const options = <int>[3, 5, 10, 20, 50, 0];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '对话上下文轮数',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '仅将最近 N 轮对话发送给模型，避免超出上下文长度',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SciColors.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            for (final o in options)
              ListTile(
                title: Text(
                  _label(o),
                  style: const TextStyle(
                    color: SciColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                trailing: o == current
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: SciColors.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  AppState.instance.contextTurns.value = o;
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
