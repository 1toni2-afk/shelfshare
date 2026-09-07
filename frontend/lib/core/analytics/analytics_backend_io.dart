import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'analytics_backend.dart';

AnalyticsBackend createAnalyticsBackend() => _FirebaseAnalyticsBackend();

/// Aceeași cheie ca pe web (`ss-analytics-consent`) ar fi fost derutantă în
/// secure storage, unde restul cheilor sunt `snake_case` - vezi
/// `core/theme/theme_controller.dart`. Valorile rămân însă identice
/// („granted" / „denied"), ca să nu existe două vocabulare pentru aceeași
/// alegere.
const _consentStorageKey = 'analytics_consent';

/// Trimite spre Firebase Analytics pe Android/iOS.
///
/// Colectarea e OPRITĂ implicit - și în Dart, prin
/// `setAnalyticsCollectionEnabled(false)`, și nativ, prin meta-data
/// `firebase_analytics_collection_enabled=false` din AndroidManifest.xml.
/// Sunt necesare amândouă: valoarea din manifest e singura care acoperă
/// intervalul dintre pornirea procesului și primul cod Dart executat, iar
/// setarea din Dart e singura care poate fi schimbată la runtime când userul
/// își dă acordul. Fără cea din manifest, SDK-ul apucă să trimită un
/// `first_open` înainte să fi întrebat pe cineva ceva.
class _FirebaseAnalyticsBackend implements AnalyticsBackend {
  final _storage = const FlutterSecureStorage();
  FirebaseAnalytics? _analytics;

  /// Copie în memorie a alegerii din storage: `consentGranted` e sincron
  /// (îl citește UI-ul la fiecare build), storage-ul e async.
  bool _granted = false;
  bool _answered = false;

  @override
  bool get consentGranted => _granted;

  @override
  bool get consentAnswered => _answered;

  @override
  Future<void> initialize() async {
    // Firebase Analytics n-are implementare pe desktop; pe Linux/Windows/macOS
    // apelurile ar arunca `MissingPluginException` la fiecare navigare.
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      // `PushNotificationsService` inițializează și el Firebase, iar ordinea
      // dintre ele nu e garantată. Pentru aplicația implicită, un al doilea
      // `initializeApp()` fără opțiuni întoarce instanța existentă în loc să
      // arunce, dar verificarea explicită face intenția vizibilă.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final stored = await _storage.read(key: _consentStorageKey);
      _answered = stored != null;
      _granted = stored == 'granted';

      final analytics = FirebaseAnalytics.instance;
      // Reafirmăm starea la fiecare pornire, în ambele sensuri: SDK-ul
      // persistă singur ultima valoare primită, deci o retragere a
      // consimțământului trebuie retrimisă, nu doar presupusă.
      await analytics.setAnalyticsCollectionEnabled(_granted);
      _analytics = analytics;
    } catch (error) {
      // Cel mai probabil: `google-services.json` lipsește (Android) sau
      // `GoogleService-Info.plist` lipsește (iOS - vezi README). Analytics-ul
      // e opțional; restul aplicației merge normal.
      debugPrint('[analytics] Firebase Analytics indisponibil: $error');
    }
  }

  @override
  Future<void> setConsent(bool granted) async {
    _granted = granted;
    _answered = true;
    await _storage.write(key: _consentStorageKey, value: granted ? 'granted' : 'denied');
    try {
      await _analytics?.setAnalyticsCollectionEnabled(granted);
    } catch (error) {
      debugPrint('[analytics] Nu am putut schimba colectarea: $error');
    }
  }

  @override
  void screenView({required String location, required String routeName}) {
    if (!_granted) return;
    // `screenName` e TIPARUL rutei, nu calea completă: Firebase tratează
    // screen_name ca dimensiune, iar `/books/<id>` ar produce un rând pe
    // fiecare carte din catalog. Calea reală merge într-un parametru separat.
    unawaited(_analytics?.logScreenView(
      screenName: routeName,
      parameters: {'route_location': location},
    ));
  }

  @override
  void event(String name, Map<String, Object> parameters) {
    if (!_granted) return;
    unawaited(_analytics?.logEvent(name: name, parameters: parameters));
  }

  /// `logEvent`/`logScreenView` întorc `Future`, dar nimeni nu așteaptă un
  /// eveniment de analytics - iar o eroare de rețea în SDK n-are voie să
  /// devină o excepție neprinsă care oprește navigarea.
  void unawaited(Future<void>? future) {
    future?.catchError((Object error) {
      debugPrint('[analytics] Eveniment eșuat: $error');
    });
  }
}
