import 'package:flutter/material.dart';

/// ألوان التطبيق الأساسية
class AppColors {
  AppColors._();

  // ── Colors ──────────────────────────────────────────
  static const Color primary = Color(0xFF1E6BFF);      // Professional Blue
  static const Color primaryDark = Color(0xFF0052CC);
  static const Color secondary = Color(0xFFFF6B35);    // Action Orange
  
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);

  // ── Text ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1D23);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Status ──────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── Extra ──────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);
  static const Color online = Color(0xFF10B981);
  static const Color shadow = Color(0x0F000000);
  static const Color card = Color(0xFFFFFFFF);

  // ── Dark Theme ──────────────────────────────────────────────
  static const Color scaffoldDark = Color(0xFF0F1216);
  static const Color surfaceDark = Color(0xFF1A1D23);
  static const Color cardDark = Color(0xFF1E232B);
  static const Color dividerDark = Color(0xFF2D333D);
  static const Color textDarkPrimary = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);

  // ── Compatibility Aliases (Bridge for Redesign) ─────────────
  static const Color accent = secondary;
  static const Color info = Color(0xFF3B82F6);
  static const Color starActive = Color(0xFFFFB800);
  static const Color starInactive = Color(0xFFD1D5DB);
  static const LinearGradient accentGradient = primaryGradient;

  // ── Gradients ────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Shadows ────────────────────────────────────────────────────
  static List<BoxShadow> get shadowLevel1 => [
    const BoxShadow(color: shadow, blurRadius: 8, offset: Offset(0, 2)),
  ];

  static List<BoxShadow> get shadowLevel2 => [
    const BoxShadow(color: shadow, blurRadius: 16, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get shadowLevel3 => [
    const BoxShadow(color: shadow, blurRadius: 24, offset: Offset(0, 8)),
  ];
}
