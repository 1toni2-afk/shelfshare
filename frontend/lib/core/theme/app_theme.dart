import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta ShelfShare - tonuri calde, evocă o librărie prietenoasă,
/// nu o platformă corporate sterilă.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF8F4EC);
  static const foreground = Color(0xFF2A1A0E);
  static const card = Color(0xFFFDFAF4);
  static const primary = Color(0xFF7C3A1E);
  static const primaryForeground = Color(0xFFFDF9F3);
  static const secondary = Color(0xFFE8E2D5);
  static const muted = Color(0xFFEDE8DE);
  static const mutedForeground = Color(0xFF7A6A5A);
  static const accent = Color(0xFFC8783A);
  static const accentForeground = Color(0xFFFDF9F3);
  static const destructive = Color(0xFFC0392B);
  static const border = Color(0x212A1A0E); // rgba(42,26,14,0.13)
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final displayFont = GoogleFonts.playfairDisplayTextTheme();
    final bodyFont = GoogleFonts.dmSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.accent,
        onSecondary: AppColors.accentForeground,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        error: AppColors.destructive,
      ),
      textTheme: bodyFont.copyWith(
        displayLarge: displayFont.displayLarge?.copyWith(color: AppColors.foreground),
        displayMedium: displayFont.displayMedium?.copyWith(color: AppColors.foreground),
        displaySmall: displayFont.displaySmall?.copyWith(color: AppColors.foreground),
        headlineLarge: displayFont.headlineLarge?.copyWith(color: AppColors.foreground),
        headlineMedium: displayFont.headlineMedium?.copyWith(color: AppColors.foreground),
        headlineSmall: displayFont.headlineSmall?.copyWith(
          color: AppColors.foreground,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: displayFont.titleLarge?.copyWith(
          color: AppColors.foreground,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: bodyFont.bodyLarge?.copyWith(color: AppColors.foreground),
        bodyMedium: bodyFont.bodyMedium?.copyWith(color: AppColors.foreground),
        bodySmall: bodyFont.bodySmall?.copyWith(color: AppColors.mutedForeground),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}
