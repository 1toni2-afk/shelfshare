import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'analytics_backend.dart';
// Implementarea se alege la compilare: gtag.js pe web, Firebase Analytics în
// rest. Vezi `analytics_backend.dart` pentru de ce nu poate fi o singură
// implementare cu ramuri `kIsWeb`.
import 'analytics_backend_io.dart'
    if (dart.library.js_interop) 'analytics_backend_web.dart' as backend;

/// Numele evenimentelor trimise spre GA4. Constante, nu literali împrăștiați
/// prin ecrane: în GA4 un nume scris greșit nu dă nicio eroare, doar creează
/// tăcut un al doilea eveniment care nu apare în niciun raport - și-l
/// descoperi peste o lună, când lipsesc datele.
///
/// Reguli GA4 pe care le respectă lista de mai jos: maximum 40 de caractere,
/// litere mici cu `_`, fără prefixele rezervate (`firebase_`, `google_`,
/// `ga_`). `login` și `sign_up` sunt nume recomandate oficial, de aceea
/// păstrează forma standard.
///
/// NICIUN parametru trimis cu aceste evenimente nu are voie să conțină date
/// personale (email, nume, id de user, text scris de user) - GA4 interzice
/// explicit asta, iar politica noastră de confidențialitate declară că spre
/// Google pleacă doar date de navigare.
abstract final class AnalyticsEvents {
  static const login = 'login';
  static const signUp = 'sign_up';

  /// Userul a publicat o carte spre schimb sau vânzare.
  static const bookListed = 'book_listed';

  /// Userul a adăugat o carte în raftul personal (fără s-o listeze).
  static const bookAddedToShelf = 'book_added_to_shelf';

  /// Un swipe în Book Match. Parametru: `liked` (bool).
  static const bookMatchSwipe = 'book_match_swipe';

  /// A cerut un schimb pentru cartea altcuiva.
  static const exchangeRequested = 'exchange_requested';

  /// A trimis o ofertă de preț pentru o carte pusă la vânzare.
  static const priceOfferSent = 'price_offer_sent';

  // Intenționat NU există un `conversation_started`: `POST /conversations` e
  // idempotent (vezi `findOrCreateConversation` din backend, care întoarce
  // conversația existentă dacă e cazul), deci clientul nu poate deosebi o
  // conversație nouă de redeschiderea uneia vechi. Un eveniment trimis de
  // acolo ar fi numărat fiecare intrare în chat ca pe o conversație nouă.
  // Dacă devine necesar, backend-ul trebuie să spună întâi care din două a
  // fost (un flag în răspuns).

  /// O căutare în catalog. Parametru: `search_term` - singurul loc unde
  /// trimitem text scris de user, pentru că e un termen de căutare de carte,
  /// nu o dată personală; e și parametrul standard GA4 pentru `search`.
  static const search = 'search';
}

/// Punctul unic prin care restul aplicației vorbește cu analytics-ul.
///
/// Toate metodele sunt „fire and forget" și nu aruncă niciodată: un ecran nu
/// are voie să se strice pentru că o statistică n-a plecat.
class Analytics {
  Analytics(this._backend);

  final AnalyticsBackend _backend;

  bool get consentGranted => _backend.consentGranted;
  bool get consentAnswered => _backend.consentAnswered;

  Future<void> initialize() async {
    try {
      await _backend.initialize();
    } catch (error) {
      debugPrint('[analytics] Inițializare eșuată: $error');
    }
  }

  Future<void> setConsent(bool granted) async {
    try {
      await _backend.setConsent(granted);
    } catch (error) {
      debugPrint('[analytics] Nu am putut salva consimțământul: $error');
    }
  }

  void screenView({required String location, required String routeName}) {
    try {
      _backend.screenView(location: location, routeName: routeName);
    } catch (error) {
      debugPrint('[analytics] screenView eșuat: $error');
    }
  }

  void event(String name, [Map<String, Object> parameters = const {}]) {
    try {
      _backend.event(name, parameters);
    } catch (error) {
      debugPrint('[analytics] Evenimentul „$name" a eșuat: $error');
    }
  }
}

final analyticsProvider = Provider<Analytics>((ref) {
  return Analytics(backend.createAnalyticsBackend());
});

/// Trimite un `page_view` / `screen_view` la fiecare navigare.
///
/// NU e un `NavigatorObserver` pus în `GoRouter(observers: ...)`, deși ăsta e
/// exemplul din documentație. Motivul e concret: aplicația folosește
/// `ShellRoute` + `StatefulShellRoute.indexedStack`, iar navigările dintre
/// tab-uri și dintre rutele din shell se întâmplă pe navigatorul interior -
/// un observer înregistrat pe cel exterior nu le vede deloc. Rezultatul ar fi
/// fost că toate ecranele de după login (adică aproape tot produsul) lipsesc
/// din rapoarte.
///
/// `GoRouterDelegate` e un `ChangeNotifier` care se notifică la ORICE
/// schimbare de configurație, indiferent de navigatorul implicat, deci e
/// singurul punct care le prinde pe toate.
void attachAnalyticsToRouter(GoRouter router, Analytics analytics) {
  String? lastLocation;

  void report() {
    // `state` citește `currentConfiguration.last`, care aruncă dacă routerul
    // n-a rezolvat încă nicio rută (se poate întâmpla la prima notificare).
    final GoRouterState state;
    try {
      state = router.state;
    } catch (_) {
      return;
    }

    final location = state.uri.path;
    // Redirecturile routerului (`/` → `/login` → `/onboarding`) produc mai
    // multe notificări pentru aceeași destinație finală. Fără verificarea
    // asta, o singură navigare ar fi numărată de două-trei ori.
    if (location == lastLocation) return;
    lastLocation = location;

    analytics.screenView(
      location: location,
      // `fullPath` e tiparul rutei (`/books/:id`). Lipsește doar pentru rute
      // nepotrivite (404), unde calea reală e oricum informația utilă.
      routeName: state.fullPath ?? location,
    );
  }

  router.routerDelegate.addListener(report);
  // Prima rută e deja rezolvată în momentul în care se apelează funcția asta,
  // deci nu va mai genera o notificare - fără apelul de aici, ecranul de
  // intrare (login sau home) n-ar apărea niciodată în rapoarte.
  report();
}
