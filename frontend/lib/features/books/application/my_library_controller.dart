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

  /// Soft-delete pe backend, elimin local imediat - lista principală nu ține
  /// cont de coșul de gunoi, care are propriul provider dedicat.
  Future<void> deleteBook(String userBookId) async {
    await ref.read(booksRepositoryProvider).deleteUserBook(userBookId);
    final current = state.value ?? const [];
    state = AsyncData(current.where((book) => book.id != userBookId).toList());
    // Invalidăm coșul de gunoi ca la deschiderea lui să apară noua carte.
    ref.invalidate(deletedBooksProvider);
  }

  /// Aplică o transformare de descriere pe cărțile date (bulk). Făcută secvențial
  /// ca să nu supraîncărcăm backend-ul, dar loose (dacă una eșuează, celelalte
  /// tot merg). Returnează câte au fost afectate.
  Future<int> bulkTransformDescriptions(
    List<UserBook> books,
    String Function(String current) transform,
  ) async {
    final repo = ref.read(booksRepositoryProvider);
    var changed = 0;
    for (final b in books) {
      try {
        final next = transform(b.description ?? '');
        if (next == (b.description ?? '')) continue;
        await repo.updateDescription(b.id, description: next);
        changed++;
      } catch (_) {
        // fire-and-continue
      }
    }
    // După modificări, reîncărcăm ca sursă de adevăr backend-ul.
    await refresh();
    return changed;
  }
}

/// Provider pentru coșul de gunoi - listat separat de biblioteca principală.
final deletedBooksProvider = FutureProvider<List<UserBook>>((ref) {
  return ref.watch(booksRepositoryProvider).getDeletedBooks();
});

/// Provider pentru „emptied shelves" - cărțile transferate permanent.
final emptiedShelvesProvider = FutureProvider<List<UserBook>>((ref) {
  return ref.watch(booksRepositoryProvider).getEmptiedShelves();
});

final myLibraryControllerProvider =
    AsyncNotifierProvider<MyLibraryController, List<UserBook>>(
  MyLibraryController.new,
);
