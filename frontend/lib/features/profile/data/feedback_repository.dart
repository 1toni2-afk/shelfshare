import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/image_upload.dart';

class FeedbackRepository {
  FeedbackRepository(this._ref);
  final Ref _ref;

  Future<void> submit(String message, {List<int>? photoBytes, String? photoFilename}) async {
    final dio = _ref.read(apiClientProvider).dio;
    if (photoBytes != null && photoFilename != null) {
      final formData = FormData.fromMap({
        'message': message,
        'photo': imageMultipartFile(photoBytes, photoFilename),
      });
      await dio.post('/feedback', data: formData, options: imageUploadOptions());
    } else {
      await dio.post('/feedback', data: {'message': message});
    }
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(ref);
});
