import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/locale/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const ProviderScope(child: ShelfShareApp()));
}

class ShelfShareApp extends ConsumerStatefulWidget {
  const ShelfShareApp({super.key});

  @override
  ConsumerState<ShelfShareApp> createState() => _ShelfShareAppState();
}

class _ShelfShareAppState extends ConsumerState<ShelfShareApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Doar relevant când preferința e "system" - forțează un rebuild ca să
    // recitim WidgetsBinding.instance.platformDispatcher.platformBrightness.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider).value;
    final themeModePref = ref.watch(themeControllerProvider).value ?? AppThemeMode.system;
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = themeModePref == AppThemeMode.dark ||
        (themeModePref == AppThemeMode.system && platformBrightness == Brightness.dark);

    return MaterialApp.router(
      title: 'ShelfShare',
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.dark : AppTheme.light,
      // Rezolvăm noi înșine system/light/dark mai sus - MaterialApp nu mai
      // trebuie să comute singur pe baza platformei.
      themeMode: ThemeMode.light,
      locale: locale?.locale,
      supportedLocales: AppLocale.values.map((l) => l.locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // AppColors expune culorile ca static getters (nu prin Theme.of(context)),
      // deci un toggle de temă nu propagă singur prin InheritedWidget. Cheia
      // forțează un remount complet al ecranului curent la schimbarea modului,
      // fără să fie nevoie de un refactor al celor ~27 de fișiere care le folosesc.
      builder: (context, child) => KeyedSubtree(key: ValueKey(isDark), child: child!),
      routerConfig: router,
    );
  }
}
