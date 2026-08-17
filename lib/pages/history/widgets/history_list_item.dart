import 'package:flutter/material.dart';

import '../../../core/theme/sci_colors.dart';

/// 历史对话列表项
class HistoryListItem extends StatelessWidget {
  const HistoryListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.count,
    this.tag,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final String title;
  final String subtitle;
  final String time;
  final int count;
  final String? tag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: SciColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SciColors.borderOf(context)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [SciColors.primary, SciColors.secondary],
                ),
                  boxShadow: [BoxShadow(color: SciColors.glow, blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SciColors.textPrimaryOf(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SciColors.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (tag != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SciColors.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: SciColors.secondary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              tag!,
                              style: const TextStyle(
                                color: SciColors.secondary,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SciColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: SciColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$count 条',
                            style: TextStyle(
                              color: SciColors.primary,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          time,
                          style: TextStyle(
                            color: SciColors.textSecondaryOf(context),
                            fontSize: 11,
                          ),
                        ),
                        IconButton(
                          onPressed: onMenu,
                          tooltip: '更多操作',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: SciColors.textSecondaryOf(context),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
