import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/sci_colors.dart';
import '../../models/model_config.dart';
import 'widgets/about_dialog.dart';
import 'widgets/context_turns_tile.dart';
import 'widgets/font_size_tile.dart';
import 'widgets/theme_setting_tile.dart';
import 'widgets/accent_color_tile.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除所有数据'),
        content: const Text(
          '将删除全部对话记录、附件、模型配置与 API Key，此操作不可恢复。',
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AppState.instance.clearAllData();
              if (context.mounted) _toast(context, '已清除全部数据');
            },
            child: const Text('清除', style: TextStyle(color: SciColors.danger)),
          ),
        ],
      ),
    );
  }

  /// 导出模型配置（不含 API Key，防止泄露）
  Future<void> _exportConfigs(BuildContext context) async {
    final models = AppState.instance.models.value;
    if (models.isEmpty) {
      _toast(context, '暂无模型配置可导出');
      return;
    }
    try {
      final data = jsonEncode({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'models': [for (final m in models) m.toJson()],
      });
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/myai_models_export.json');
      await file.writeAsString(data);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'MyAI 模型配置'),
      );
    } catch (e) {
      if (context.mounted) _toast(context, '导出失败：$e');
    }
  }

  /// 导入模型配置（导入后需在「模型」页补充 API Key）
  Future<void> _importConfigs(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path == null) return;
      final raw = await File(path).readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['models'] as List<dynamic>?) ?? [];
      if (list.isEmpty) {
        if (context.mounted) _toast(context, '文件中没有模型配置');
        return;
      }
      var count = 0;
      for (final item in list) {
        final config = ModelConfig.fromJson(item as Map<String, dynamic>);
        await AppState.instance.addModel(config.copyWith(apiKey: ''));
        count++;
      }
      if (!context.mounted) return;
      _toast(context, '已导入 $count 个模型，请在「模型」页补充 API Key');
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败：$e');
    }
  }

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
            const AccentColorTile(),
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
              icon: Icons.file_upload_outlined,
              label: '导出模型配置',
              onTap: () => _exportConfigs(context),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.file_download_outlined,
              label: '导入模型配置',
              onTap: () => _importConfigs(context),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              label: '清除所有数据',
              danger: true,
              onTap: () => _confirmClear(context),
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
        style: TextStyle(
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
