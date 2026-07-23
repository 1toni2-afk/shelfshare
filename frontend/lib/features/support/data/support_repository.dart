import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';

class CaptchaChallenge {
  const CaptchaChallenge({required this.question, required this.token});
  final String question;
  final String token;

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return CaptchaChallenge(
      question: json['question'] as String,
      token: json['token'] as String,
    );
  }
}

/// Mesaje de la useri care nu se pot loga (deci fără sesiune autentificată) -
/// endpointurile /support sunt publice, protejate doar de un captcha simplu.
class SupportRepository {
  SupportRepository(this._ref);
  final Ref _ref;

  Future<CaptchaChallenge> getCaptcha() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/support/captcha');
    return CaptchaChallenge.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> submit({
    required String name,
    required String email,
    String? phone,
    required String message,
    required String captchaToken,
    required int captchaAnswer,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/support', data: {
      'name': name,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'message': message,
      'captchaToken': captchaToken,
      'captchaAnswer': captchaAnswer,
    });
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref);
});
