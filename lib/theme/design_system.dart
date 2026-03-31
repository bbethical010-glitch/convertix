import 'package:flutter/material.dart';

// ── Adaptive colors helper ──

class CxColors {
  final BuildContext context;
  CxColors.of(this.context);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get background => _isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
  Color get surfaceContainer => _isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight;
  Color get surfaceContainerLow => _isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowLight;
  Color get surfaceContainerHigh => _isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHighLight;
  Color get surfaceContainerHighest => _isDark ? AppColors.surfaceContainerHighestDark : AppColors.surfaceContainerHighestLight;
  Color get onSurface => _isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;
  Color get onSurfaceVariant => _isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight;
  Color get outlineVariant => _isDark ? AppColors.outlineVariantDark : AppColors.outlineVariantLight;
  Color get primary => _isDark ? AppColors.primary : AppColors.primaryLight;
  Color get glassCard => _isDark ? AppColors.glassCardDark : AppColors.glassCardLight;
  Color get glassBorder => _isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
  Color get bottomNavBg => _isDark
      ? const Color(0xFF0F172A).withValues(alpha: 0.6)
      : Colors.white.withValues(alpha: 0.85);
}

class AppColors {
  AppColors._();

  // ── DARK PALETTE ──
  static const Color backgroundDark = Color(0xFF0A0E18);
  static const Color surfaceContainerDark = Color(0xFF151926);
  static const Color surfaceContainerLowDark = Color(0xFF0F121C);
  static const Color surfaceContainerHighDark = Color(0xFF1A1F2D);
  static const Color surfaceContainerHighestDark = Color(0xFF202534);
  static const Color surfaceBrightDark = Color(0xFF262C3C);

  // ── LIGHT PALETTE ──
  static const Color backgroundLight = Color(0xFFF5F6FA);
  static const Color surfaceContainerLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerHighLight = Color(0xFFF0F1F5);
  static const Color surfaceContainerLowLight = Color(0xFFFAFAFE);
  static const Color surfaceContainerHighestLight = Color(0xFFE8E9F0);

  // Primary palette (shared)
  static const Color primary = Color(0xFFA3A6FF);
  static const Color primaryDim = Color(0xFF6063EE);
  static const Color primaryLight = Color(0xFF4F46E5);
  static const Color onPrimary = Color(0xFF0F00A4);

  // Secondary
  static const Color secondary = Color(0xFFA28EFC);

  // Tertiary (pink)
  static const Color tertiary = Color(0xFFFFA5D9);

  // Error
  static const Color error = Color(0xFFFF6E84);

  // On-surface dark
  static const Color onSurfaceDark = Color(0xFFE5E7F6);
  static const Color onSurfaceVariantDark = Color(0xFFA7AAB9);
  static const Color outlineVariantDark = Color(0xFF444854);

  // On-surface light
  static const Color onSurfaceLight = Color(0xFF1A1C2E);
  static const Color onSurfaceVariantLight = Color(0xFF6B7085);
  static const Color outlineVariantLight = Color(0xFFD0D3DD);

  // Glass
  static Color glassCardDark = const Color(0xFF202534).withValues(alpha: 0.6);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.05);
  static Color glassCardLight = Colors.white.withValues(alpha: 0.7);
  static Color glassBorderLight = Colors.black.withValues(alpha: 0.06);
}
