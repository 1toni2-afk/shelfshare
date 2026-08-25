import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/book_of_month.dart';

class BookOfMonthRepository {
  BookOfMonthRepository(this._ref);
  final Ref _ref;

  Future<BookOfMonthWinner> getCurrentWinner() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/book-of-month/winner');
    return BookOfMonthWinner.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MyBookOfMonthVote?> getMyVote() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/book-of-month/my-vote');
    if (response.data == null) return null;
    return MyBookOfMonthVote.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> vote(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/book-of-month/vote', data: {'bookId': bookId});
  }
}

final bookOfMonthRepositoryProvider = Provider<BookOfMonthRepository>((ref) {
  return BookOfMonthRepository(ref);
});
