import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/wishlist_item.dart';

class WishlistRepository {
  WishlistRepository(this._ref);
  final Ref _ref;

  Future<List<WishlistItem>> getWishlist() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/wishlist');
    return (response.data as List<dynamic>)
        .map((e) => WishlistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WishlistItem> addToWishlist(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/wishlist', data: {'bookId': bookId});
    return WishlistItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeFromWishlist(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/wishlist/$bookId');
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref);
});
