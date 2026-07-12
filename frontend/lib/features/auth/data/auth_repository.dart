import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../../core/network/token_storage.dart';
import '../../../data/models/user.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> register({required String email, required String password}) async {
    await _apiClient.dio.post(
      '/auth/register',
      data: {'email': email, 'password': password},
    );
  }

  Future<AppUser> login({required String email, required String password}) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _tokenStorage.saveTokens(
      accessToken: response.data['accessToken'] as String,
      refreshToken: response.data['refreshToken'] as String,
    );
    return AppUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {
      // continuăm oricum să curățăm local, chiar dacă serverul nu răspunde
    }
    await _tokenStorage.clear();
  }

  Future<void> forgotPassword(String email) async {
    await _apiClient.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _apiClient.dio.post(
      '/auth/reset-password',
      data: {'token': token, 'newPassword': newPassword},
    );
  }

  Future<AppUser?> tryRestoreSession() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) return null;

    try {
      final response = await _apiClient.dio.get('/profile/me');
      return AppUser.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      await _tokenStorage.clear();
      return null;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});
