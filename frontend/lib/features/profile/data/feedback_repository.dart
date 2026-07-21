import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';

class FeedbackRepository {
  FeedbackRepository(this._ref);
  final Ref _ref;

  Future<void> submit(String message) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/feedback', data: {'message': message});
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(ref);
});
