import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// أنماط النصوص في التطبيق
class AppTextStyles {
  AppTextStyles._();

  // ── الخط الأساسي (Cairo - يدعم العربية بشكل ممتاز) ────────────
  static String get _fontFamily => GoogleFonts.cairo().fontFamily!;

  // ── العناوين ──────────────────────────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineMedium => GoogleFonts.cairo(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineSmall => GoogleFonts.cairo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  // ── العناوين الفرعية ──────────────────────────────────────────
  static TextStyle get titleLarge => GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get titleMedium => GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get titleSmall => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  // ── النصوص العادية ────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  static TextStyle get bodyMedium => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  static TextStyle get bodySmall => GoogleFonts.cairo(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  // ── التسميات ──────────────────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get labelMedium => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get labelSmall => GoogleFonts.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // ── الأزرار ───────────────────────────────────────────────────
  static TextStyle get button => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
        height: 1,
      );

  static TextStyle get buttonSmall => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
        height: 1,
      );

  // ── مساعدات ───────────────────────────────────────────────────
  static String get fontFamily => _fontFamily;
}
