import 'package:flutter/material.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/sci_colors.dart';

/// 字体大小设置项
class FontSizeTile extends StatelessWidget {
  const FontSizeTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppState.instance.fontScale,
      builder: (context, scale, _) => _FontTile(scale: scale),
    );
  }
}

class _FontTile extends StatelessWidget {
  const _FontTile({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final percent = (scale * 100).round();
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => _FontSliderSheet(scale: scale),
      ),
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
            const Icon(Icons.text_fields_rounded, color: SciColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '字体大小',
                style: TextStyle(
                  color: SciColors.textPrimaryOf(context),
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '$percent%',
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

class _FontSliderSheet extends StatefulWidget {
  const _FontSliderSheet({required this.scale});

  final double scale;

  @override
  State<_FontSliderSheet> createState() => _FontSliderSheetState();
}

class _FontSliderSheetState extends State<_FontSliderSheet> {
  late double _scale = widget.scale;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '字体大小',
                  style: TextStyle(
                    color: SciColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(_scale * 100).round()}%',
                  style: const TextStyle(
                    color: SciColors.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'A',
                  style: TextStyle(color: SciColors.textSecondary, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 12,
                    activeColor: SciColors.primary,
                    inactiveColor: SciColors.border,
                    onChanged: (v) {
                      setState(() => _scale = v);
                      AppState.instance.fontScale.value = v;
                    },
                  ),
                ),
                const Text(
                  'A',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    AppState.instance.fontScale.value = 1.0;
                    setState(() => _scale = 1.0);
                  },
                  child: const Text(
                    '恢复默认',
                    style: TextStyle(color: SciColors.primary, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '完成',
                    style: TextStyle(color: SciColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
