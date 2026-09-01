import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_storage.dart';

/// URL-ul backend-ului. Pentru emulator Android, "localhost" nu ajunge
/// la mașina gazdă - se folosește 10.0.2.2 în schimb. Pe simulator iOS
/// și pe web, localhost merge normal.
class ApiConfig {
  ApiConfig._();

  /// Default-ul diferă între debug și release DINADINS: un build de release
  /// făcut fără --dart-define=API_BASE_URL ajungea cu "localhost:3000"
  /// compilat în binar, adică fiecare request de pe telefon lovea telefonul
  /// însuși. Nu se vedea ca eroare de configurare, ci ca „A apărut o eroare.
  /// Încearcă din nou." la orice login (vezi AuthController._extractMessage,
  /// care cade pe mesajul generic când requestul nu primește niciun răspuns).
  /// În release cădem deci pe producție, iar dart-define rămâne disponibil
  /// pentru cine chiar vrea alt backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        kReleaseMode ? 'https://api.shelfshare.ro' : 'http://localhost:3000',
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

  /// Se asigură că token-ul din storage e valid, reîmprospătându-l dacă a
  /// expirat (sau e pe punctul să expire).
  ///
  /// Există pentru socket-ul de chat, care are nevoie de un token proaspăt la
  /// (re)conectare. Înainte, „proaspăt" se obținea printr-un GET pe
  /// `/profile/me` doar ca să declanșeze interceptorul de 401 de mai sus -
  /// adică profilul complet descărcat de fiecare dată când socket-ul se
  /// autentifica. În waterfall-ul de pornire se vedeau 4 cereri `/profile/me`
  /// una după alta. Aici nu se face niciun request cât timp token-ul e încă
  /// valid; ne uităm doar la `exp` din payload-ul JWT.
  Future<void> ensureFreshToken() async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null && !_isExpiringSoon(token)) return;
    await _tryRefreshToken();
  }

  /// `exp` din payload-ul JWT (secunde Unix), cu o marjă de 30s ca un token
  /// care expiră chiar în timpul handshake-ului să fie tratat ca expirat.
  /// Orice token pe care nu-l putem citi e considerat expirat - reîmprospătarea
  /// e ieftină, iar un handshake cu token invalid nu e.
  bool _isExpiringSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return expiresAt.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      // Aceleași timeout-uri ca pe clientul principal. Fără ele, Dio așteaptă
      // la infinit: o cerere de refresh blocată ținea în loc `ensureFreshToken`,
      // iar prin el funcția de auth a socketului, care nu mai apela niciodată
      // callback-ul de conectare (vezi ChatSocketService._provideFreshAuth).
      final response = await Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ).post(
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
