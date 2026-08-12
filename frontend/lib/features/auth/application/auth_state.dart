import '../../../data/models/user.dart';
import '../../support/data/support_repository.dart' show CaptchaChallenge;

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

/// Backend-ul a cerut rezolvarea unui captcha după prea multe încercări
/// eșuate de login (vezi AuthService.requireCaptchaIfSuspicious pe backend).
class AuthCaptchaRequired extends AuthState {
  const AuthCaptchaRequired({
    required this.captcha,
    required this.email,
    required this.password,
    this.message,
  });
  final CaptchaChallenge captcha;
  final String email;
  final String password;
  final String? message;
}
