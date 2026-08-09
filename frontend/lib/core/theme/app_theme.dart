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
  // Negru aproape pur (nu maro-închis) - aspect "luxury", nu doar un maro
  // supra-întunecat. Vezi [[feedback_dark_theme_luxury_black]].
  static const _darkBackground = Color(0xFF0E0E0F);
  static Color get background => _dark ? _darkBackground : _lightBackground;

  static const _lightForeground = Color(0xFF2A1A0E);
  static const _darkForeground = Color(0xFFF5F3F0);
  static Color get foreground => _dark ? _darkForeground : _lightForeground;

  static const _lightCard = Color(0xFFFDFAF4);
  static const _darkCard = Color(0xFF19191B);
  static Color get card => _dark ? _darkCard : _lightCard;

  static const primary = Color(0xFF7C3A1E);
  static const primaryForeground = Color(0xFFFDF9F3);

  static const _lightSecondary = Color(0xFFE8E2D5);
  static const _darkSecondary = Color(0xFF242426);
  static Color get secondary => _dark ? _darkSecondary : _lightSecondary;

  static const _lightMuted = Color(0xFFEDE8DE);
  static const _darkMuted = Color(0xFF29292B);
  static Color get muted => _dark ? _darkMuted : _lightMuted;

  // Textul secundar pe cardurile light era la 4.26 față de fundalul cardului
  // muted - sub pragul WCAG AA (4.5) pentru text mic. Închis la #655A4A
  // pentru un ratio ~5.0 pe muted, ~5.8 pe background - încă „muted" vizual,
  // dar citibil la soare pe telefon.
  static const _lightMutedForeground = Color(0xFF655A4A);
  static const _darkMutedForeground = Color(0xFFA8A6A3);
  static Color get mutedForeground => _dark ? _darkMutedForeground : _lightMutedForeground;

  static const accent = Color(0xFFC8783A);
  static const accentForeground = Color(0xFFFDF9F3);

  // `destructive` a rămas const ca să nu sparg cele 20+ `const Icon(...color:
  // AppColors.destructive)` din cod. Pentru locurile care afișează text
  // destructive pe fundal întunecat (mesaje de eroare), există `dangerText`
  // ca getter tematic - are ratio ~4.9 pe dark bg, față de 3.55 al variantei
  // originale. Folosește-l unde textul e nu-poți-să-nu-îl-vezi.
  static const destructive = Color(0xFFC0392B);
  static Color get dangerText => _dark ? const Color(0xFFE85347) : destructive;

  // Culori semantice adăugate în Milestone 15 - înainte codul folosea peste
  // 20 de ori `Colors.green` / `Color(0xFF2E7D32)` / `Colors.amber` direct,
  // care nu urmăreau tema. Splituri pentru contrast: light-mode culoarea
  // clasică Material, dark-mode o nuanță mai deschisă care nu se pierde pe
  // fundal întunecat.
  static const _lightSuccess = Color(0xFF2E7D32);
  static const _darkSuccess = Color(0xFF66BB6A);
  static Color get success => _dark ? _darkSuccess : _lightSuccess;

  static const _lightWarning = Color(0xFFB8860B); // dark goldenrod
  static const _darkWarning = Color(0xFFFFC947); // amber deschis
  static Color get warning => _dark ? _darkWarning : _lightWarning;

  static const _lightBorder = Color(0x212A1A0E); // rgba(42,26,14,0.13)
  static const _darkBorder = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
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
        // Titlu centrat pe toate ecranele. Înainte era pe stânga, iar Home și
        // Discover și-l centrau local - de unde inconsecvența dintre taburi.
        centerTitle: true,
      ),
      // Fără asta, TabBar folosește `colorScheme.onSurfaceVariant` implicit
      // pentru eticheta neselectată - un gri-maroniu din paleta default
      // Material, nu din `AppColors` - deci apărea text maro-închis pe fundal
      // negru (My Bookshelf, Exchanges, Groups, Global Stats, Leaderboard).
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.mutedForeground,
        indicatorColor: AppColors.accent,
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
        // Eticheta nu mai urcă deasupra câmpului la focus - dispare, ca un hint.
        // Varianta flotantă producea nealinieri în tot ecranul de login și în
        // formulare (eticheta așezată pe muchia câmpului, text tăiat pe
        // orizontală, spațiere inegală între câmpuri), pentru că trebuia
        // rezervat loc deasupra valorii în fiecare câmp. Cu
        // FloatingLabelBehavior.never, eticheta stă pe o singură linie în
        // interiorul câmpului și se ascunde imediat ce userul scrie, deci
        // câmpul are o singură geometrie, indiferent de stare.
        floatingLabelBehavior: FloatingLabelBehavior.never,
        // UnderlineInputBorder, nu OutlineInputBorder: chenarul e invizibil în
        // ambele cazuri, dar borderRadius păstrează forma rotunjită a
        // dreptunghiului colorat.
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        // Simetric acum: nu mai trebuie loc rezervat deasupra pentru eticheta
        // flotantă, deci textul stă centrat vertical în câmp.
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          // `symmetric(vertical: 16)` lăsa horizontal implicit pe 0 - butoanele
          // scurte ("Edit", "OK") aveau textul lipit de margini. 24px orizontal
          // e padding-ul standard M3 pentru butoane cu text.
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.foreground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
      // Fără el, go_router (via `MaterialPage`) folosea tranziția implicită
      // pe platformă - pe multe browsere desktop asta înseamnă slide-ul de
      // tip iOS (pagina veche iese spre stânga, cea nouă intră din dreapta),
      // cel mai clar semnal vizual că „asta e o aplicație de telefon". Pe
      // ecrane late devine un fade scurt; pe telefon rămâne tranziția
      // obișnuită, unde slide-ul chiar are sens.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const _WidthAwarePageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get light => build(dark: false);
  static ThemeData get dark => build(dark: true);
}

/// Prag desktop pentru tranziții - același folosit de sidebar
/// (`kSidebarBreakpoint` în main_scaffold.dart), ca alegerea „e desktop?" să
/// fie consistentă în toată aplicația.
const _kTransitionDesktopBreakpoint = 900.0;

class _WidthAwarePageTransitionsBuilder extends PageTransitionsBuilder {
  const _WidthAwarePageTransitionsBuilder();

  static const _mobileTransition = ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _kTransitionDesktopBreakpoint;
    if (!isDesktop) {
      return _mobileTransition.buildTransitions(route, context, animation, secondaryAnimation, child);
    }
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}
