import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// ثيم التطبيق الكامل – Light و Dark
class AppTheme {
  AppTheme._();

  static const double _borderRadius = 16.0;

  // ══════════════════════════════════════════════════════════════
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          background: AppColors.background,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: GoogleFonts.cairo().fontFamily,
        
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            side: BorderSide(color: AppColors.primary.withOpacity(0.35), width: 1.5),
          ),
        ),

        // ── Card ────────────────────────────────────────────────
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius * 1.5),
            side: const BorderSide(color: AppColors.divider, width: 1),
          ),
          color: AppColors.card,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),

        // ── ElevatedButton ──────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
            ),
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),

        // ── OutlinedButton ──────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.divider, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
            ),
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),

        // ── TextButton ──────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),

        // ── Input ───────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          hintStyle: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 14),
          labelStyle: GoogleFonts.cairo(fontSize: 14),
          errorStyle: GoogleFonts.cairo(color: AppColors.error, fontSize: 12),
        ),

        // ── FloatingActionButton ────────────────────────────────
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
        ),

        // ── BottomNavigationBar ─────────────────────────────────
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
        ),

        // ── Chip ────────────────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: AppColors.primary,
          labelStyle: GoogleFonts.cairo(fontSize: 13),
          secondaryLabelStyle: GoogleFonts.cairo(fontSize: 13, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),

        // ── Divider ─────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // ── SnackBar ────────────────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.primary,
          contentTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // ── Dialog ──────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: GoogleFonts.cairo(fontSize: 14),
          elevation: 0,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.cairo().fontFamily,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          primaryContainer: AppColors.primary.withOpacity(0.1),
          secondary: AppColors.secondary,
          surface: AppColors.surfaceDark,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textDarkPrimary,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldDark,

        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.scaffoldDark,
          foregroundColor: AppColors.textDarkPrimary,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDarkPrimary,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: const IconThemeData(color: AppColors.textDarkPrimary),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius * 1.5),
            side: const BorderSide(color: AppColors.dividerDark, width: 1),
          ),
          color: AppColors.cardDark,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
            ),
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceDark,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: AppColors.dividerDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: AppColors.dividerDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          hintStyle: GoogleFonts.cairo(color: AppColors.textDarkSecondary, fontSize: 14),
        ),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textDarkSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
        ),

        dividerTheme: const DividerThemeData(
          color: AppColors.dividerDark,
          thickness: 1,
          space: 1,
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          contentTextStyle: GoogleFonts.cairo(color: AppColors.textDarkPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: AppColors.surfaceDark,
          titleTextStyle: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDarkPrimary),
          contentTextStyle: GoogleFonts.cairo(fontSize: 14, color: AppColors.textDarkSecondary),
        ),
      );
}
