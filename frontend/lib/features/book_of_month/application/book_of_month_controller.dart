import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/book_of_month_repository.dart';

final bookOfMonthWinnerProvider = FutureProvider((ref) {
  return ref.watch(bookOfMonthRepositoryProvider).getCurrentWinner();
});

final myBookOfMonthVoteProvider = FutureProvider((ref) {
  return ref.watch(bookOfMonthRepositoryProvider).getMyVote();
});

class BookOfMonthController extends Notifier<void> {
  @override
  void build() {}

  Future<void> vote(String bookId) async {
    await ref.read(bookOfMonthRepositoryProvider).vote(bookId);
    ref.invalidate(bookOfMonthWinnerProvider);
    ref.invalidate(myBookOfMonthVoteProvider);
  }
}

final bookOfMonthControllerProvider = NotifierProvider<BookOfMonthController, void>(
  BookOfMonthController.new,
);
