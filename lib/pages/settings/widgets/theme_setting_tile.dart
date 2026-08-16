import 'package:flutter/material.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/sci_colors.dart';

/// 主题设置项
class ThemeSettingTile extends StatelessWidget {
  const ThemeSettingTile({super.key});

  String _label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '亮色',
        ThemeMode.dark => '暗色',
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.instance.themeMode,
      builder: (context, mode, _) {
        return _SettingTile(
          icon: Icons.palette_outlined,
          label: '主题',
          value: _label(mode),
          onTap: () => _showPicker(context, mode),
        );
      },
    );
  }

  void _showPicker(BuildContext context, ThemeMode current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择主题',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final mode in const [
              ThemeMode.system,
              ThemeMode.light,
              ThemeMode.dark,
            ])
              ListTile(
                title: Text(
                  _label(mode),
                  style: const TextStyle(
                    color: SciColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                trailing: mode == current
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: SciColors.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  AppState.instance.themeMode.value = mode;
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

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            Icon(icon, color: SciColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: SciColors.textPrimaryOf(context),
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              value,
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
  }
}
