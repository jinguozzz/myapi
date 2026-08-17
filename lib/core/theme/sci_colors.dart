import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 科幻风格配色
class SciColors {
  SciColors._();

  /// 深空背景（暗色主题）
  static const Color background = Color(0xFF070B14);

  /// 面板底色
  static const Color surface = Color(0xFF0E1626);

  /// 面板浅色（输入框等）
  static const Color surfaceLight = Color(0xFF162031);

  /// 霓虹青（主色）——运行时可变，支持自定义霓虹主题色
  static Color primary = const Color(0xFF00E5FF);

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

  /// 霓虹发光（阴影）——随主色联动
  static Color glow = const Color(0x4D00E5FF);

  // ---- 亮色（浅色深空）----
  static const Color lightBackground = Color(0xFFEAF3FB);
  static const Color lightSurface = Color(0xFFF7FBFF);
  static const Color lightSurfaceLight = Color(0xFFEDF3FA);
  static const Color lightTextPrimary = Color(0xFF0E1B2E);
  static const Color lightTextSecondary = Color(0xFF4A5A72);
  static const Color lightBorder = Color(0xFFD6E2F0);

  // ---- 动漫暖色调 ----
  static const Color animeBackground = Color(0xFFFFF6EE);
  static const Color animeSurface = Color(0xFFFFFCF8);
  static const Color animeSurfaceLight = Color(0xFFFFEFE1);
  static const Color animeTextPrimary = Color(0xFF5A4637);
  static const Color animeTextSecondary = Color(0xFF9C8572);
  static const Color animeBorder = Color(0xFFF0DFCC);

  /// 应用自定义霓虹主题色
  static void applyAccent(Color color) {
    primary = color;
    glow = color.withValues(alpha: 0.3);
  }

  /// 是否当前为暗色主题
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// 是否当前为动漫暖色主题
  static bool isAnime(BuildContext context) =>
      Theme.of(context).extension<ThemeKindData>()?.anime ?? false;

  static Color backgroundOf(BuildContext context) {
    if (isAnime(context)) return animeBackground;
    return isDark(context) ? background : lightBackground;
  }

  static Color surfaceOf(BuildContext context) {
    if (isAnime(context)) return animeSurface;
    return isDark(context) ? surface : lightSurface;
  }

  static Color surfaceLightOf(BuildContext context) {
    if (isAnime(context)) return animeSurfaceLight;
    return isDark(context) ? surfaceLight : lightSurfaceLight;
  }

  static Color textPrimaryOf(BuildContext context) {
    if (isAnime(context)) return animeTextPrimary;
    return isDark(context) ? textPrimary : lightTextPrimary;
  }

  static Color textSecondaryOf(BuildContext context) {
    if (isAnime(context)) return animeTextSecondary;
    return isDark(context) ? textSecondary : lightTextSecondary;
  }

  static Color borderOf(BuildContext context) {
    if (isAnime(context)) return animeBorder;
    return isDark(context) ? border : lightBorder;
  }

  /// 主色霓虹发光阴影
  static List<BoxShadow> neonShadow({double blur = 12, Color? color}) => [
        BoxShadow(
          color: (color ?? primary).withValues(alpha: 0.45),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];
}
