import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'token_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageProvider));
});

/// Incrementat de [ApiClient] când sesiunea devine invalidă (refresh token
/// expirat/revocat) - AuthController ascultă schimbarea și trece userul pe
/// Unauthenticated, ca UI-ul să reflecte imediat delogarea în loc să rămână
/// "logat" vizual cu request-uri care eșuează tăcut la 401.
class SessionExpiredCounter extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final sessionExpiredProvider = NotifierProvider<SessionExpiredCounter, int>(
  SessionExpiredCounter.new,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStorageProvider),
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).bump(),
  );
});

// `pushNotificationsServiceProvider` s-a mutat în `notifications/push_gateway.dart`,
// în spatele unui import amânat: definit aici, importul normal al serviciului
// trăgea tot SDK-ul Firebase în bundle-ul inițial, deși notificările n-au
// niciun rol până după login.
