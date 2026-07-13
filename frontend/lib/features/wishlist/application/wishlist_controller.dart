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

  Future<void> toggle(String bookId) async {
    final repository = ref.read(wishlistRepositoryProvider);
    final current = state.value ?? const [];
    if (isWishlisted(bookId)) {
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
