import 'package:flutter/material.dart';

/// 科幻风格配色
class SciColors {
  SciColors._();

  /// 深空背景（暗色主题）
  static const Color background = Color(0xFF070B14);

  /// 面板底色
  static const Color surface = Color(0xFF0E1626);

  /// 面板浅色（输入框等）
  static const Color surfaceLight = Color(0xFF162031);

  /// 霓虹青（主色）
  static const Color primary = Color(0xFF00E5FF);

  /// 主色暗化
  static const Color primaryDim = Color(0xFF00A8C4);

  /// 霓虹紫（辅色）
  static const Color secondary = Color(0xFF7C4DFF);

  /// 荧光绿（在线 / 成功）
  static const Color accent = Color(0xFF00FFA3);

  /// 危险红
  static const Color danger = Color(0xFFFF5C7A);

  /// 主文字
  static const Color textPrimary = Color(0xFFE6F1FF);

  /// 次要文字
  static const Color textSecondary = Color(0xFF7A8BA6);

  /// 边框
  static const Color border = Color(0xFF1E2A3D);

  /// 霓虹发光（阴影）
  static const Color glow = Color(0x4D00E5FF);

  /// 是否当前为暗色主题
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? background : const Color(0xFFEAF3FB);

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surface : const Color(0xFFF7FBFF);

  static Color surfaceLightOf(BuildContext context) =>
      isDark(context) ? surfaceLight : const Color(0xFFEDF3FA);

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimary : const Color(0xFF0E1B2E);

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondary : const Color(0xFF4A5A72);

  static Color borderOf(BuildContext context) =>
      isDark(context) ? border : const Color(0xFFD6E2F0);

  /// 主色霓虹发光阴影
  static List<BoxShadow> neonShadow({double blur = 12, Color? color}) => [
        BoxShadow(
          color: (color ?? primary).withValues(alpha: 0.45),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];
}
