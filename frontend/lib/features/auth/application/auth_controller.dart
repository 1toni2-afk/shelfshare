import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    // Amânăm restaurarea sesiunii într-un microtask - nu modificăm `state`
    // sincron în timpul build(), altfel valoarea e suprascrisă de return.
    Future.microtask(_restoreSession);
    return const AuthLoading();
  }

  Future<void> _restoreSession() async {
    final user = await _repository.tryRestoreSession();
    state = user != null ? AuthAuthenticated(user) : const AuthUnauthenticated();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthAuthenticated(user);
    } on DioException catch (e) {
      state = AuthError(_extractMessage(e));
    }
  }

  Future<void> completeExternalLogin({required String code}) async {
    state = const AuthLoading();
    try {
      final user = await _repository.completeExternalLogin(code: code);
      state = AuthAuthenticated(user);
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> register({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      await _repository.register(email: email, password: password);
      state = const AuthUnauthenticated();
    } on DioException catch (e) {
      state = AuthError(_extractMessage(e));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  /// Actualizează userul din starea de auth după o editare de profil,
  /// ca ecranele care depind de nume/oraș (Home etc.) să reflecte imediat
  /// schimbarea, fără să aștepte un restart al aplicației.
  void setUser(AppUser user) {
    if (state is AuthAuthenticated) {
      state = AuthAuthenticated(user);
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      if (msg is List) return msg.join(', ');
      return msg.toString();
    }
    return 'A apărut o eroare. Încearcă din nou.';
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
