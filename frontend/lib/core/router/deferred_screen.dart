import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Încărcare amânată (deferred) a ecranelor, ca bundle-ul inițial să conțină
/// doar ce trebuie ca userul să vadă ecranul de login.
///
/// Contextul: `flutter build web` compilează tot programul într-un singur
/// `main.dart.js`. Cu toate cele ~80 de rute importate normal în
/// `app_router.dart`, fișierul ajunsese la 5,5 MB (1,5 MB gzip) - adică
/// panoul de admin, chat-ul, hărțile și Book Match-ul se descărcau și se
/// compilau înainte ca cineva să poată apăsa „Login". Măsurat pe conexiunea
/// de acasă: ~2s doar descărcarea, plus ~2,3s parse/compile, ecran gol.
///
/// Cu `import ... deferred as`, dart2js scoate din bundle-ul principal tot
/// codul accesibil DOAR prin importuri amânate și îl pune în fișiere
/// `main.dart.js_N.part.js`, descărcate la primul `loadLibrary()`. De aici și
/// regula pe care trebuie s-o respecte orice rută nouă: dacă un ecran amânat
/// e importat normal din altă parte (un model, un widget partajat, alt
/// ecran neamânat), codul lui se întoarce în bundle-ul principal și amânarea
/// nu mai are niciun efect - fără nicio eroare, doar fără câștig. De asta
/// `SearchScreenArgs` stă în `data/models/` și `showLanguagePicker` în
/// `shared/widgets/`, nu în ecranele care le folosesc.
typedef LibraryLoader = Future<void> Function();

/// Randează `builder` abia după ce biblioteca amânată a fost descărcată.
///
/// Cât timp se descarcă se afișează un indicator discret - în practică e
/// vizibil doar la prima navigare către o secțiune neîncărcată încă, și
/// deloc pentru rutele preîncărcate în fundal (vezi `preload`).
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    required this.loader,
    required this.builder,
    super.key,
  });

  final LibraryLoader loader;
  final WidgetBuilder builder;

  /// Bibliotecile deja încărcate. `loadLibrary()` e idempotent și întoarce
  /// același Future, dar ținem noi evidența ca să putem randa sincron (fără
  /// niciun frame de placeholder) ce s-a încărcat deja - altfel fiecare
  /// revenire pe o rută vizitată ar clipi.
  static final Set<LibraryLoader> _loaded = {};
  static final Map<LibraryLoader, Future<void>> _pending = {};

  /// Pornește descărcarea unei biblioteci fără s-o afișeze. Folosit pentru
  /// rutele de nivel 1 (Home, Discover, detaliu carte), preîncărcate în
  /// fundal imediat după primul frame: userul e încă pe login, conexiunea e
  /// liberă, iar când ajunge acolo ecranul e deja în memorie.
  static Future<void> preload(LibraryLoader loader) {
    if (_loaded.contains(loader)) return Future.value();
    return _pending.putIfAbsent(loader, () async {
      await loader();
      _loaded.add(loader);
      _pending.remove(loader);
    });
  }

  static bool isLoaded(LibraryLoader loader) => _loaded.contains(loader);

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = DeferredScreen.preload(widget.loader);
  }

  @override
  void didUpdateWidget(DeferredScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      _future = DeferredScreen.preload(widget.loader);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DeferredScreen.isLoaded(widget.loader)) {
      return widget.builder(context);
    }
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) return _DeferredLoadError(error: snapshot.error);
          return widget.builder(context);
        }
        return const _DeferredLoading();
      },
    );
  }
}

class _DeferredLoading extends StatelessWidget {
  const _DeferredLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// Descărcarea unei părți amânate poate eșua acolo unde un import normal n-ar
/// fi avut cum (conexiune pierdută între încărcarea aplicației și navigare,
/// sau un deploy nou care a înlocuit fișierele `.part.js` sub picioarele unei
/// sesiuni vechi). Fără tratare, ecranul ar rămâne la nesfârșit pe indicator.
class _DeferredLoadError extends StatelessWidget {
  const _DeferredLoadError({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.mutedForeground),
              const SizedBox(height: 12),
              Text(
                'Această secțiune nu s-a putut încărca. Verifică conexiunea și '
                'reîncarcă pagina.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
