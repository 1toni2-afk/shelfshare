import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';

/// POST /pre-registration - opt-in pentru anunțul de lansare Android.
/// Ruta e publică; dacă userul e logat, token-ul JWT e trimis automat de
/// interceptorul Dio și backend-ul leagă înscrierea de userId-ul lui.
class PreRegistrationRepository {
  PreRegistrationRepository(this._ref);
  final Ref _ref;

  Future<void> register(String email) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/pre-registration', data: {'email': email});
  }
}

final preRegistrationRepositoryProvider = Provider<PreRegistrationRepository>(
  (ref) => PreRegistrationRepository(ref),
);
