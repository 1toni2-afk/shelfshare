import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/review.dart';
import '../../safety/data/safety_repository.dart';

class ReviewsRepository {
  ReviewsRepository(this._ref);
  final Ref _ref;

  Future<BookReviews> getForBook(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/reviews/book/$bookId');
    return BookReviews.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MyReview?> getMine(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/reviews/book/$bookId/mine');
    if (response.data == null) return null;
    return MyReview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> upsert(String bookId, int rating, String? text) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/reviews', data: {
      'bookId': bookId,
      'rating': rating,
      if (text != null && text.isNotEmpty) 'text': text,
    });
  }

  Future<void> remove(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/reviews/$bookId');
  }

  Future<void> report(String reviewId, {required ReportReason reason, String? details}) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/reviews/$reviewId/report', data: {
      'reason': reason.toJson(),
      if (details != null && details.isNotEmpty) 'details': details,
    });
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref);
});

final bookReviewsProvider = FutureProvider.family<BookReviews, String>((ref, bookId) {
  return ref.watch(reviewsRepositoryProvider).getForBook(bookId);
});

final myReviewProvider = FutureProvider.family<MyReview?, String>((ref, bookId) {
  return ref.watch(reviewsRepositoryProvider).getMine(bookId);
});
