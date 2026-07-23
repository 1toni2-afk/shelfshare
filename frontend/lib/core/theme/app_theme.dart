import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta ShelfShare - tonuri calde, evocă o librărie prietenoasă,
/// nu o platformă corporate sterilă.
///
/// Culorile de brand (`primary`/`accent`/etc.) rămân identice în ambele
/// moduri. Culorile de suprafață (fundal/text/card/muted/border) devin
/// getters care comută pe modul curent, setat de [AppTheme.build] înainte
/// de a construi tema - vezi comentariul de acolo pentru de ce era nevoie
/// de acest mecanism în loc de un simplu `ColorScheme` static.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static void setDark(bool value) => _dark = value;

  static const _lightBackground = Color(0xFFF8F4EC);
  static const _darkBackground = Color(0xFF1C140D);
  static Color get background => _dark ? _darkBackground : _lightBackground;

  static const _lightForeground = Color(0xFF2A1A0E);
  static const _darkForeground = Color(0xFFF3E7D8);
  static Color get foreground => _dark ? _darkForeground : _lightForeground;

  static const _lightCard = Color(0xFFFDFAF4);
  static const _darkCard = Color(0xFF261C13);
  static Color get card => _dark ? _darkCard : _lightCard;

  static const primary = Color(0xFF7C3A1E);
  static const primaryForeground = Color(0xFFFDF9F3);

  static const _lightSecondary = Color(0xFFE8E2D5);
  static const _darkSecondary = Color(0xFF3A2C1D);
  static Color get secondary => _dark ? _darkSecondary : _lightSecondary;

  static const _lightMuted = Color(0xFFEDE8DE);
  static const _darkMuted = Color(0xFF332619);
  static Color get muted => _dark ? _darkMuted : _lightMuted;

  static const _lightMutedForeground = Color(0xFF7A6A5A);
  static const _darkMutedForeground = Color(0xFFB9A891);
  static Color get mutedForeground => _dark ? _darkMutedForeground : _lightMutedForeground;

  static const accent = Color(0xFFC8783A);
  static const accentForeground = Color(0xFFFDF9F3);
  static const destructive = Color(0xFFC0392B);

  static const _lightBorder = Color(0x212A1A0E); // rgba(42,26,14,0.13)
  static const _darkBorder = Color(0x33F3E7D8); // rgba(243,231,216,0.2)
  static Color get border => _dark ? _darkBorder : _lightBorder;
}

class AppTheme {
  AppTheme._();

  /// Construiește tema pentru [dark]. Setează întâi flag-ul din [AppColors]
  /// - restul aplicației citește `AppColors.xxx` direct (nu prin
  /// `Theme.of(context)`), deci ordinea contează: flag-ul trebuie să
  /// reflecte modul activ ÎNAINTE ca orice widget să citească o culoare,
  /// nu doar în timpul construirii acestui obiect `ThemeData`.
  static ThemeData build({required bool dark}) {
    AppColors.setDark(dark);

    final displayFont = GoogleFonts.playfairDisplayTextTheme();
    final bodyFont = GoogleFonts.dmSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: dark
          ? ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.primaryForeground,
              secondary: AppColors.accent,
              onSecondary: AppColors.accentForeground,
              surface: AppColors.card,
              onSurface: AppColors.foreground,
              error: AppColors.destructive,
            )
          : ColorScheme.light(
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
        titleMedium: bodyFont.titleMedium?.copyWith(color: AppColors.foreground),
        titleSmall: bodyFont.titleSmall?.copyWith(color: AppColors.foreground),
        bodyLarge: bodyFont.bodyLarge?.copyWith(color: AppColors.foreground),
        bodyMedium: bodyFont.bodyMedium?.copyWith(color: AppColors.foreground),
        bodySmall: bodyFont.bodySmall?.copyWith(color: AppColors.mutedForeground),
        labelLarge: bodyFont.labelLarge?.copyWith(color: AppColors.foreground),
        labelMedium: bodyFont.labelMedium?.copyWith(color: AppColors.mutedForeground),
        labelSmall: bodyFont.labelSmall?.copyWith(color: AppColors.mutedForeground),
      ),
      appBarTheme: AppBarTheme(
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
          side: BorderSide(color: AppColors.border),
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
          side: BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }

  static ThemeData get light => build(dark: false);
  static ThemeData get dark => build(dark: true);
}
