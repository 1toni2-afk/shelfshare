import 'package:dio/dio.dart';
import 'token_storage.dart';

/// URL-ul backend-ului. Pentru emulator Android, "localhost" nu ajunge
/// la mașina gazdă - se folosește 10.0.2.2 în schimb. Pe simulator iOS
/// și pe web, localhost merge normal.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}

/// Client HTTP central. Atașează automat JWT-ul la fiecare request și
/// reîncearcă o singură dată cu refresh token dacă primește 401.
class ApiClient {
  ApiClient(this._tokenStorage, {this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        // Pe web, fetch-ul de sub Dio respectă cache-ul HTTP al browserului,
        // care nu ține cont de header-ul Authorization - fără asta, un GET
        // autentificat poate întoarce răspunsul cache-uit al userului
        // anterior logat pe același browser (ex. /profile/me după login).
        headers: {'Cache-Control': 'no-cache'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final isRetry = error.requestOptions.extra['retried'] == true;

          if (isUnauthorized && !isRetry) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final options = error.requestOptions;
              options.extra['retried'] = true;
              final token = await _tokenStorage.getAccessToken();
              options.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              } catch (_) {
                // continuă cu eroarea originală dacă nici retry-ul nu merge
              }
            } else {
              // Refresh token invalid/expirat/revocat (ex. contul a fost
              // șters) - fără asta userul rămâne "logat" vizual în UI cu
              // fiecare request eșuând tăcut la 401, până la un refresh
              // manual de pagină.
              onSessionExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final void Function()? onSessionExpired;

  Dio get dio => _dio;

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      await _tokenStorage.saveTokens(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await _tokenStorage.clear();
      return false;
    }
  }
}
