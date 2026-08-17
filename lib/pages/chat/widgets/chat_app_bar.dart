import 'package:flutter/material.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/sci_colors.dart';
import '../../../models/model_config.dart';

/// 对话页面顶部栏（标题 + 当前模型状态 + 新建 + 右上菜单）
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    required this.onNewConversation,
    required this.onRegenerate,
    required this.onClearConversation,
    required this.onApplyTemplate,
    required this.onQuickCommand,
  });

  final String title;
  final VoidCallback onNewConversation;
  final VoidCallback onRegenerate;
  final VoidCallback onClearConversation;
  final VoidCallback onApplyTemplate;
  final VoidCallback onQuickCommand;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        tooltip: '新建对话',
        icon: const Icon(Icons.add_rounded),
        onPressed: onNewConversation,
      ),
      title: ValueListenableBuilder<ModelConfig?>(
        valueListenable: AppState.instance.currentModel,
        builder: (context, model, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: model == null
                          ? SciColors.textSecondary
                          : SciColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: model == null
                          ? null
                          : [
                              BoxShadow(
                                color: SciColors.accent.withValues(alpha: 0.7),
                                blurRadius: 6,
                              ),
                            ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      model == null
                          ? '未选择模型'
                          : '${model.displayName} · ${model.modelId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SciColors.textSecondaryOf(context),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) async {
            switch (value) {
              case 'switch':
                await _switchModel(context);
              case 'template':
                onApplyTemplate();
              case 'quick':
                onQuickCommand();
              case 'regenerate':
                onRegenerate();
              case 'clear':
                onClearConversation();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'switch',
              child: _MenuItem(
                icon: Icons.swap_horiz_rounded,
                label: '切换模型',
              ),
            ),
            PopupMenuItem(
              value: 'template',
              child: _MenuItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Prompt 模板',
              ),
            ),
            PopupMenuItem(
              value: 'quick',
              child: _MenuItem(
                icon: Icons.bolt_rounded,
                label: '快捷指令',
              ),
            ),
            PopupMenuItem(
              value: 'regenerate',
              child: _MenuItem(
                icon: Icons.refresh_rounded,
                label: '重新生成',
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: _MenuItem(
                icon: Icons.delete_outline_rounded,
                label: '清空对话',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _switchModel(BuildContext context) async {
    final models = AppState.instance.models.value;
    if (models.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无模型，请到「模型」页添加')),
        );
      }
      return;
    }
    final currentId = AppState.instance.currentModel.value?.id;
    final selected = await showModalBottomSheet<ModelConfig>(
      context: context,
      backgroundColor: SciColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '切换模型',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final m in models)
              ListTile(
                leading: Icon(
                  Icons.smart_toy_outlined,
                  color: SciColors.primary,
                  size: 20,
                ),
                title: Text(
                  m.displayName,
                  style: const TextStyle(
                    color: SciColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  m.modelId,
                  style: const TextStyle(
                    color: SciColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                trailing: m.id == currentId
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: SciColors.primary,
                        size: 20,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      await AppState.instance.setDefault(selected.id);
    }
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SciColors.textSecondaryOf(context)),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
