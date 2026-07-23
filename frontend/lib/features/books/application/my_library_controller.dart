import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user_book.dart';
import '../data/books_repository.dart';

class MyLibraryController extends AsyncNotifier<List<UserBook>> {
  @override
  Future<List<UserBook>> build() {
    return ref.read(booksRepositoryProvider).getMyLibrary();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(booksRepositoryProvider).getMyLibrary());
  }

  Future<void> setAvailability(String userBookId, {required bool availableForSwap}) async {
    final updated = await ref
        .read(booksRepositoryProvider)
        .setAvailability(userBookId, availableForSwap: availableForSwap);
    final current = state.value ?? const [];
    state = AsyncData([
      for (final book in current)
        if (book.id == userBookId) updated else book,
    ]);
  }

  Future<void> editListing(
    String userBookId, {
    required BookCondition condition,
    String? language,
    String? edition,
    required bool isHardcover,
    required bool isForSale,
    double? salePrice,
    required bool isNegotiable,
  }) async {
    final updated = await ref.read(booksRepositoryProvider).updateListing(
          userBookId,
          condition: condition,
          language: language,
          edition: edition,
          isHardcover: isHardcover,
          isForSale: isForSale,
          salePrice: salePrice,
          isNegotiable: isNegotiable,
        );
    final current = state.value ?? const [];
    state = AsyncData([
      for (final book in current)
        if (book.id == userBookId) updated else book,
    ]);
  }

  Future<void> deleteBook(String userBookId) async {
    await ref.read(booksRepositoryProvider).deleteUserBook(userBookId);
    final current = state.value ?? const [];
    state = AsyncData(current.where((book) => book.id != userBookId).toList());
  }
}

final myLibraryControllerProvider =
    AsyncNotifierProvider<MyLibraryController, List<UserBook>>(
  MyLibraryController.new,
);
