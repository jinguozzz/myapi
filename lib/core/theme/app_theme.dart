import 'package:flutter/material.dart';

import 'sci_colors.dart';

/// 应用主题（科幻风格）
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(
        scheme: ColorScheme.dark(
          primary: SciColors.primary,
          onPrimary: const Color(0xFF001418),
          secondary: SciColors.secondary,
          onSecondary: Colors.white,
          surface: SciColors.surface,
          onSurface: SciColors.textPrimary,
          error: SciColors.danger,
          onError: Colors.white,
        ),
        background: SciColors.background,
        surface: SciColors.surface,
        fill: SciColors.surfaceLight,
        textPrimary: SciColors.textPrimary,
        textSecondary: SciColors.textSecondary,
        border: SciColors.border,
      );

  static ThemeData light() => _build(
        scheme: ColorScheme.light(
          primary: SciColors.primaryDim,
          onPrimary: const Color(0xFF00222B),
          secondary: SciColors.secondary,
          onSecondary: Colors.white,
          surface: const Color(0xFFF7FBFF),
          onSurface: const Color(0xFF0E1B2E),
          error: SciColors.danger,
          onError: Colors.white,
        ),
        background: const Color(0xFFEAF3FB),
        surface: const Color(0xFFF7FBFF),
        fill: const Color(0xFFEDF3FA),
        textPrimary: const Color(0xFF0E1B2E),
        textSecondary: const Color(0xFF4A5A72),
        border: const Color(0xFFD6E2F0),
      );

  static ThemeData _build({
    required ColorScheme scheme,
    required Color background,
    required Color surface,
    required Color fill,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SciColors.primary, width: 1.4),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        textStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SciColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}
