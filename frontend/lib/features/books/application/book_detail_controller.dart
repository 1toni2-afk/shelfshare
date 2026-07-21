import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/books_repository.dart';

final bookDetailProvider = FutureProvider.family((ref, String userBookId) {
  return ref.watch(booksRepositoryProvider).getUserBook(userBookId);
});

final listingHistoryProvider = FutureProvider.family((ref, String userBookId) {
  return ref.watch(booksRepositoryProvider).getListingHistory(userBookId);
});

final similarBooksProvider = FutureProvider.family((ref, String userBookId) {
  return ref.watch(booksRepositoryProvider).getSimilarBooks(userBookId);
});
