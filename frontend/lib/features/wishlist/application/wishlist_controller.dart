import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/wishlist_item.dart';
import '../data/wishlist_repository.dart';

class WishlistController extends AsyncNotifier<List<WishlistItem>> {
  @override
  Future<List<WishlistItem>> build() {
    return ref.read(wishlistRepositoryProvider).getWishlist();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(wishlistRepositoryProvider).getWishlist());
  }

  bool isWishlisted(String bookId) {
    return (state.value ?? const []).any((item) => item.book.id == bookId);
  }

  /// Sursa rândului de wishlist pentru o carte, sau null dacă nu e pe listă.
  /// Cardurile o folosesc ca să aleagă între inimă (PERSONAL) și iconița de
  /// Book Match - fără un apel separat pe card, lista e deja în memorie.
  WishlistSource? sourceFor(String bookId) {
    for (final item in state.value ?? const <WishlistItem>[]) {
      if (item.book.id == bookId) return item.source;
    }
    return null;
  }

  /// Scoatere necondiționată de pe wishlist, indiferent de sursă - folosită
  /// de butonul „×" din ecranul de Wishlist, unde intenția e mereu eliminarea
  /// (spre deosebire de `toggle`, care pe o sugestie din Book Match o
  /// confirmă ca favorit explicit în loc s-o elimine).
  Future<void> removeItem(String bookId) async {
    final repository = ref.read(wishlistRepositoryProvider);
    final current = state.value ?? const [];
    await repository.removeFromWishlist(bookId);
    state = AsyncData(current.where((item) => item.book.id != bookId).toList());
  }

  Future<void> toggle(String bookId) async {
    final repository = ref.read(wishlistRepositoryProvider);
    final current = state.value ?? const [];
    final source = sourceFor(bookId);
    if (source == WishlistSource.bookMatch) {
      // Deja pe wishlist ca sugestie din Book Match (scânteie) - primul tap
      // pe iconiță confirmă alegerea ca favorit explicit (inimă), nu o
      // elimină. Un remove real se face doar din ecranul de Wishlist.
      final confirmed = await repository.addToWishlist(bookId);
      state = AsyncData([
        confirmed,
        ...current.where((item) => item.book.id != bookId),
      ]);
    } else if (source != null) {
      await repository.removeFromWishlist(bookId);
      state = AsyncData(current.where((item) => item.book.id != bookId).toList());
    } else {
      final added = await repository.addToWishlist(bookId);
      state = AsyncData([added, ...current]);
    }
  }
}

final wishlistControllerProvider = AsyncNotifierProvider<WishlistController, List<WishlistItem>>(
  WishlistController.new,
);
