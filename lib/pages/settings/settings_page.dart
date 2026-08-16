import 'package:flutter/material.dart';

import '../../core/theme/sci_colors.dart';
import 'widgets/about_dialog.dart';
import 'widgets/context_turns_tile.dart';
import 'widgets/font_size_tile.dart';
import 'widgets/theme_setting_tile.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SciColors.backgroundOf(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '设置',
              style: TextStyle(
                color: SciColors.textPrimaryOf(context),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            const _SectionLabel('外观'),
            const SizedBox(height: 8),
            const ThemeSettingTile(),
            const SizedBox(height: 8),
            const FontSizeTile(),
            const SizedBox(height: 16),
            const _SectionLabel('对话'),
            const SizedBox(height: 8),
            const ContextTurnsTile(),
            const SizedBox(height: 16),
            const _SectionLabel('数据与配置'),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              label: '清除所有对话数据',
              danger: true,
              onTap: () => _confirmClear(context),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.file_download_outlined,
              label: '导入 / 导出配置',
              onTap: () => _toast(context, '导入 / 导出功能开发中'),
            ),
            const SizedBox(height: 16),
            const _SectionLabel('关于'),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.info_outline_rounded,
              label: '关于 MyAI Companion',
              onTap: () => showAboutInfoDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text(
          '将删除本机全部对话数据，此操作不可恢复。',
          style: TextStyle(color: SciColors.textSecondary),
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
            onPressed: () {
              Navigator.of(ctx).pop();
              _toast(context, '已清除（演示）');
            },
            child: const Text('清除', style: TextStyle(color: SciColors.danger)),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: SciColors.primary,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SciColors.danger : SciColors.textPrimaryOf(context);
    final iconColor = danger ? SciColors.danger : SciColors.primary;
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 14),
              ),
            ),
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
