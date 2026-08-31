import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/locale/locale_controller.dart';
import 'core/notifications/push_gateway.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/auth_state.dart';
import 'l10n/app_localizations.dart';

void main() async {
  // Redirecționăm erorile de framework și de zonă către print, ca stack
  // trace-urile să apară în consola browserului chiar și în release web.
  // Fără asta, o excepție într-un build widget lasă tot ecranul negru fără
  // niciun indiciu (Flutter nu afișează ErrorWidget-ul roșu în release).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('FlutterError: ${details.exception}\n${details.stack}');
  };
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Fără asta, Flutter web folosește implicit hash routing (/#/...) - un
    // URL real precum /auth/google/callback?code=X (cum e redirectul din
    // fluxul Google OAuth) e ignorat la boot, iar aplicația pornește mereu
    // pe ruta implicită, pierzând codul de schimb.
    usePathUrlStrategy();
    await initializeDateFormatting();
    runApp(const ProviderScope(child: ShelfShareApp()));
    // Ecranele de nivel 1 (Home, Discover, detaliu carte) se descarcă în
    // fundal abia DUPĂ primul frame - adică după ce login-ul e deja pe ecran
    // și interactiv. Vezi `preloadPrimaryScreens` și `deferred_screen.dart`
    // pentru împărțirea pe niveluri.
    WidgetsBinding.instance.addPostFrameCallback((_) => preloadPrimaryScreens());
  }, (error, stack) {
    // ignore: avoid_print
    print('ZoneError: $error\n$stack');
  });
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
    // Firebase se inițializează o singură dată, indiferent dacă userul e
    // logat - abonarea/dezabonarea efectivă a tokenului se face mai jos, în
    // build(), pe baza stării de autentificare.
    Future.microtask(() => ref.read(pushGatewayProvider).initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // effectiveLocaleProvider citește limbile dispozitivului direct din
    // platformDispatcher, deci are nevoie de un rebuild ca să le recitească.
    setState(() {});
  }

  @override
  void didChangePlatformBrightness() {
    // Doar relevant când preferința e "system" - forțează un rebuild ca să
    // recitim WidgetsBinding.instance.platformDispatcher.platformBrightness.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Abonăm/dezabonăm dispozitivul la push exact când starea de auth se
    // schimbă - nu la fiecare rebuild (de-asta e în ref.listen, nu ref.watch).
    ref.listen(authControllerProvider, (previous, next) {
      final push = ref.read(pushGatewayProvider);
      if (next is AuthAuthenticated) {
        push.registerForCurrentUser();
      } else if (previous is AuthAuthenticated && next is AuthUnauthenticated) {
        push.unregisterCurrentDevice();
      }
    });
    final router = ref.watch(routerProvider);
    final locale = ref.watch(effectiveLocaleProvider);
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
      locale: locale.locale,
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
