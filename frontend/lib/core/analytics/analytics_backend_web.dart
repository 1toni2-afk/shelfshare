import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'analytics_backend.dart';

AnalyticsBackend createAnalyticsBackend() => _GtagAnalytics();

/// Cheia sub care stă alegerea userului. Aceeași valoare ca în index.html și
/// ca în `shared/widgets/analytics_consent_web.dart` - dacă o schimbi aici,
/// schimb-o în toate trei, altfel bannerul reapare la fiecare încărcare.
const _consentKey = 'ss-analytics-consent';

/// Evenimentul pe care index.html îl emite în clipa în care gtag.js chiar a
/// fost încărcat. Contează pentru cazul „userul apasă Accept după ce
/// aplicația e deja pornită": până atunci n-am trimis nimic, deci ecranul pe
/// care stă chiar acum n-ar apărea niciodată în GA fără o retrimitere.
const _readyEvent = 'ss-analytics-ready';

/// Trimite spre GA4 prin gtag.js, încărcat de index.html DOAR după
/// consimțământ. Backend-ul ăsta nu încarcă niciodată singur scriptul și nu
/// pune niciun cookie: dacă `window.__ssAnalyticsLoaded` lipsește, fiecare
/// apel se pierde tăcut. Adică o construcție „fail closed" - un bug aici
/// înseamnă date lipsă, nu date trimise fără drept.
class _GtagAnalytics implements AnalyticsBackend {
  String? _lastLocation;
  String? _lastRouteName;

  @override
  Future<void> initialize() async {
    web.window.addEventListener(
      _readyEvent,
      ((web.Event _) {
        final location = _lastLocation;
        if (location != null) {
          _sendPageView(location, _lastRouteName ?? location);
        }
      }).toJS,
    );
  }

  @override
  bool get consentGranted => _storedConsent() == 'granted';

  @override
  bool get consentAnswered => _storedConsent() != null;

  String? _storedConsent() {
    try {
      return web.window.localStorage.getItem(_consentKey);
    } catch (_) {
      // Storage blocat de tot (mod privat pe unele browsere): ne purtăm ca și
      // cum n-ar exista o alegere, adică nu trimitem nimic.
      return null;
    }
  }

  @override
  Future<void> setConsent(bool granted) async {
    try {
      web.window.localStorage.setItem(_consentKey, granted ? 'granted' : 'denied');
    } catch (_) {
      // Fără storage nu putem ține minte alegerea peste reîncărcări, dar
      // pentru sesiunea curentă tot o putem onora mai jos.
    }
    if (!granted) {
      // gtag.js nu se poate „descărca" dintr-o pagină deja pornită, dar nici
      // nu e nevoie: din acest moment `_gtag` nu mai trimite nimic (verifică
      // `consentGranted` la fiecare apel), iar `consent update` îi spune
      // explicit lui Google să nu mai folosească stocarea pentru analytics.
      // La următoarea încărcare a paginii scriptul nici nu mai pornește.
      _consentUpdate(false);
      return;
    }
    // Funcție expusă global de index.html - acolo stă și ID-ul de măsurare,
    // ca să existe o singură sursă de adevăr pentru el.
    final load = web.window.getProperty<JSFunction?>('shelfShareLoadAnalytics'.toJS);
    load?.callAsFunction(web.window);
    // Pentru cazul în care scriptul era deja încărcat dintr-o rundă
    // anterioară de „Accept -> Refuz -> Accept" în aceeași sesiune:
    // `loadAnalytics` iese devreme a doua oară, deci consimțământul retras
    // trebuie reafirmat explicit.
    _consentUpdate(true);
  }

  /// Mecanismul oficial GA pentru consimțământ (Consent Mode). Separat de
  /// simplul „nu mai apelăm gtag": ăsta îi spune lui Google să nu mai
  /// citească/scrie cookie-uri de analytics, inclusiv pentru orice s-ar
  /// declanșa în afara codului nostru.
  void _consentUpdate(bool granted) {
    if (!_loaded) return;
    final gtag = web.window.getProperty<JSFunction?>('gtag'.toJS);
    if (gtag == null) return;
    final payload = JSObject()
      ..setProperty('analytics_storage'.toJS, (granted ? 'granted' : 'denied').toJS);
    try {
      gtag.callAsFunction(web.window, 'consent'.toJS, 'update'.toJS, payload);
    } catch (error) {
      debugPrint('[analytics] consent update a eșuat: $error');
    }
  }

  /// `true` doar dacă index.html chiar a pornit gtag.js.
  bool get _loaded {
    final flag = web.window.getProperty<JSAny?>('__ssAnalyticsLoaded'.toJS);
    return flag != null && flag.isA<JSBoolean>() && (flag as JSBoolean).toDart;
  }

  @override
  void screenView({required String location, required String routeName}) {
    _lastLocation = location;
    _lastRouteName = routeName;
    _sendPageView(location, routeName);
  }

  void _sendPageView(String location, String routeName) {
    // `page_location` se compune din origin + calea rutei, NU din
    // `window.location.href`. go_router notifică ascultătorii înainte ca
    // browserul să-și fi actualizat bara de adrese, deci `href` ar fi cu o
    // navigare în urmă - fiecare page_view ar fi atribuit ecranului
    // precedent, ceea ce e mai rău decât să lipsească.
    _gtag('page_view', {
      'page_location': '${web.window.location.origin}$location',
      'page_title': routeName,
      // Dimensiune proprie, de configurat în GA4 ca „custom dimension" pe
      // event scope. Rostul ei: `page_location` are cardinalitate mare
      // (fiecare id de carte e o pagină separată), tiparul rutei nu - deci
      // „câți oameni deschid detaliul unei cărți" se răspunde dintr-un
      // singur rând, nu însumând mii.
      'route_name': routeName,
    });
  }

  @override
  void event(String name, Map<String, Object> parameters) => _gtag(name, parameters);

  void _gtag(String name, Map<String, Object> parameters) {
    // `_loaded` singur nu e suficient: userul poate retrage consimțământul
    // din Setări în aceeași sesiune, iar scriptul rămâne încărcat în pagină.
    if (!_loaded || !consentGranted) return;
    final gtag = web.window.getProperty<JSFunction?>('gtag'.toJS);
    if (gtag == null) return;
    try {
      gtag.callAsFunction(web.window, 'event'.toJS, name.toJS, _toJsObject(parameters));
    } catch (error) {
      // Un blocator de reclame poate înlocui `gtag` cu ceva care aruncă.
      debugPrint('[analytics] gtag a eșuat pentru „$name": $error');
    }
  }

  JSObject _toJsObject(Map<String, Object> parameters) {
    final object = JSObject();
    for (final entry in parameters.entries) {
      object.setProperty(entry.key.toJS, switch (entry.value) {
        final String value => value.toJS,
        final int value => value.toJS,
        final double value => value.toJS,
        final bool value => value.toJS,
        final Object value => value.toString().toJS,
      });
    }
    return object;
  }
}
