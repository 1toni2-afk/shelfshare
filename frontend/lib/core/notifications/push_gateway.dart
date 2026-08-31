import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/providers.dart';
import 'push_notifications_service.dart' deferred as push;

/// Fațadă amânată peste [PushNotificationsService].
///
/// Serviciul de push aduce cu el firebase_core, firebase_messaging și
/// flutter_local_notifications - iar înainte intra în bundle-ul inițial,
/// fiindcă `providers.dart` (citit la pornire) îl importa normal. Notificările
/// nu au însă niciun rol până când cineva nu e logat: un vizitator ajuns pe
/// ecranul de login descărca degeaba tot SDK-ul Firebase înainte să vadă
/// formularul.
///
/// Aici, biblioteca se descarcă la primul apel real - adică odată cu
/// inițializarea de după primul frame, nu înaintea lui. Toate metodele sunt
/// „fire and forget": dacă descărcarea eșuează (offline), aplicația merge mai
/// departe fără push, exact ca înainte pe un dispozitiv fără permisiune.
class PushGateway {
  PushGateway(this._apiClient);

  final ApiClient _apiClient;

  /// Tipat `dynamic` fiindcă Dart interzice tipurile dintr-o bibliotecă
  /// amânată în adnotări („deferred type can't be used in a declaration") -
  /// altfel ar fi trebuit ca tipul să fie cunoscut înainte de încărcare, adică
  /// exact ce vrem să evităm. Apelurile de mai jos sunt oricum acoperite de
  /// singurul apelant (main.dart) și de cele trei metode ale serviciului.
  dynamic _service;

  Future<dynamic> _ensure() async {
    await push.loadLibrary();
    return _service ??= push.PushNotificationsService(_apiClient);
  }

  Future<void> initialize() async => (await _ensure()).initialize() as Future<void>;

  Future<void> registerForCurrentUser() async =>
      (await _ensure()).registerForCurrentUser() as Future<void>;

  Future<void> unregisterCurrentDevice() async =>
      (await _ensure()).unregisterCurrentDevice() as Future<void>;
}

final pushGatewayProvider = Provider<PushGateway>((ref) {
  return PushGateway(ref.watch(apiClientProvider));
});
