import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/sci_colors.dart';
import '../../models/model_config.dart';
import 'widgets/model_edit_dialog.dart';
import 'widgets/model_list_item.dart';

/// 模型管理列表页面（真实持久化 CRUD）
class ModelListPage extends StatelessWidget {
  const ModelListPage({super.key});

  Future<void> _add(BuildContext context) async {
    final result = await showModelEditDialog(context);
    if (result == null || !context.mounted) return;
    await AppState.instance.addModel(result);
  }

  Future<void> _edit(BuildContext context, ModelConfig model) async {
    final result = await showModelEditDialog(context, initial: model);
    if (result == null || !context.mounted) return;
    await AppState.instance.updateModel(result);
  }

  void _remove(BuildContext context, ModelConfig model) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模型'),
        content: Text(
          '确定删除「${model.displayName}」？\n对应的 API Key 也将一并清除。',
          style: const TextStyle(color: SciColors.textSecondary),
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
              await AppState.instance.removeModel(model.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除模型')),
                );
              }
            },
            child: const Text('删除', style: TextStyle(color: SciColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SciColors.backgroundOf(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    '模型管理',
                    style: TextStyle(
                      color: SciColors.textPrimaryOf(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _add(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [SciColors.primary, SciColors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: SciColors.neonShadow(blur: 12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Color(0xFF00222B),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '添加模型',
                            style: TextStyle(
                              color: Color(0xFF00222B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<ModelConfig>>(
                valueListenable: AppState.instance.models,
                builder: (context, models, _) {
                  if (models.isEmpty) {
                    return _EmptyState(
                      onAdd: () => _add(context),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: models.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final m = models[i];
                      return ModelListItem(
                        name: m.displayName,
                        modelId: m.modelId,
                        baseUrl: m.baseUrl,
                        isDefault: m.isDefault,
                        onSelect: () => AppState.instance.setDefault(m.id),
                        onEdit: () => _edit(context, m),
                        onDelete: () => _remove(context, m),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SciColors.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: SciColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: SciColors.neonShadow(blur: 16),
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              color: SciColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有模型',
            style: TextStyle(
              color: SciColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方「添加模型」\n填入 API 地址与密钥后即可对话',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SciColors.textSecondaryOf(context),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [SciColors.primary, SciColors.secondary],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: SciColors.neonShadow(blur: 12),
              ),
              child: const Text(
                '添加第一个模型',
                style: TextStyle(
                  color: Color(0xFF00222B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
