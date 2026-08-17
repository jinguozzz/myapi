import 'package:flutter/material.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/sci_colors.dart';

/// 霓虹主题色设置项
class AccentColorTile extends StatelessWidget {
  const AccentColorTile({super.key});

  static const _presets = <(String, Color)>[
    ('深空青', Color(0xFF00E5FF)),
    ('霓虹紫', Color(0xFF7C4DFF)),
    ('荧光绿', Color(0xFF00FFA3)),
    ('能量橙', Color(0xFFFFA500)),
    ('脉冲粉', Color(0xFFFF5C8A)),
    ('极光蓝', Color(0xFF3D9BFF)),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppState.instance.accentColor,
      builder: (context, current, _) {
        return InkWell(
          onTap: () => _showPicker(context, current),
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
                Icon(
                  Icons.palette_outlined,
                  color: SciColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '霓虹主题色',
                    style: TextStyle(
                      color: SciColors.textPrimaryOf(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: current,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: current.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
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

  void _showPicker(BuildContext context, Color current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '霓虹主题色',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final (name, color) in _presets)
                    InkWell(
                      onTap: () {
                        AppState.instance.accentColor.value = color;
                        Navigator.of(ctx).pop();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == current
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: color == current
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF00222B),
                                    size: 20,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: const TextStyle(
                              color: SciColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
