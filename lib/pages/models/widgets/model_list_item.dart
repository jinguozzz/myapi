import 'package:flutter/material.dart';

import '../../../core/theme/sci_colors.dart';

/// 模型列表项
class ModelListItem extends StatelessWidget {
  const ModelListItem({
    super.key,
    required this.name,
    required this.modelId,
    required this.baseUrl,
    required this.isDefault,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final String modelId;
  final String baseUrl;
  final bool isDefault;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SciColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDefault
                ? SciColors.primary.withValues(alpha: 0.6)
                : SciColors.borderOf(context),
          ),
          boxShadow: isDefault ? SciColors.neonShadow(blur: 12) : null,
        ),
        child: Row(
          children: [
            _radio(context, isDefault),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: SciColors.textPrimaryOf(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SciColors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '默认',
                            style: TextStyle(
                              color: SciColors.primary,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modelId,
                    style: const TextStyle(
                      color: SciColors.primaryDim,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SciColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: '编辑',
              icon: const Icon(
                Icons.edit_outlined,
                color: SciColors.textSecondary,
                size: 18,
              ),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: '删除',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: SciColors.textSecondary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radio(BuildContext context, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? SciColors.primary : SciColors.borderOf(context),
          width: 2,
        ),
        boxShadow: selected ? SciColors.neonShadow(blur: 8) : null,
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: SciColors.primary)
          : null,
    );
  }
}
