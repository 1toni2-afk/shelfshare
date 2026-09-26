import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';

/// Starea listei „Descoperă ShelfShare" așa cum o ține contul.
class OnboardingTodoPayload {
  const OnboardingTodoPayload({required this.done, required this.dismissed});

  /// Numele pașilor bifați (`OnboardingTodo.name`). Text, nu enum: un pas
  /// scos din aplicație nu trebuie să facă parsarea să crape pe un client
  /// vechi - necunoscutele se ignoră la citire.
  final Set<String> done;
  final bool dismissed;

  factory OnboardingTodoPayload.fromJson(Map<String, dynamic> json) {
    return OnboardingTodoPayload(
      done: ((json['done'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      dismissed: json['dismissed'] == true,
    );
  }
}

class OnboardingTodoRepository {
  OnboardingTodoRepository(this._ref);
  final Ref _ref;

  Future<OnboardingTodoPayload> get() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/me/onboarding-todo');
    return OnboardingTodoPayload.fromJson(response.data as Map<String, dynamic>);
  }

  /// Scriere parțială: `done` se REUNEȘTE pe server cu ce e deja bifat, iar
  /// `dismissed` omis lasă valoarea neschimbată. Așa o bifă trimisă de pe
  /// telefon nu șterge una pusă de pe laptop cu o clipă înainte.
  Future<OnboardingTodoPayload> save({
    Set<String> done = const {},
    bool? dismissed,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/profile/me/onboarding-todo', data: {
      'done': done.toList(),
      'dismissed': ?dismissed,
    });
    return OnboardingTodoPayload.fromJson(response.data as Map<String, dynamic>);
  }
}

final onboardingTodoRepositoryProvider = Provider<OnboardingTodoRepository>(
  OnboardingTodoRepository.new,
);
