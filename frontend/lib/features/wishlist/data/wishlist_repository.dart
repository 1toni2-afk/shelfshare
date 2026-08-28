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

  /// [userBookId] = anunțul de pe care s-a apăsat inima. Serverul leagă
  /// favoritul de exemplarul ăla, ca inima să nu se aprindă și pe celelalte
  /// anunțuri ale aceluiași titlu.
  Future<WishlistItem> addToWishlist(String bookId, {String? userBookId}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/wishlist', data: {
      'bookId': bookId,
      'userBookId': ?userBookId,
    });
    return WishlistItem.fromJson(response.data as Map<String, dynamic>);
  }

  /// Scoate titlul complet de la favorite (toate anunțurile lui).
  Future<void> removeFromWishlist(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/wishlist/$bookId');
  }

  /// Scoate de la favorite doar anunțul dat.
  Future<void> removeListingFromWishlist(String userBookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/wishlist/listing/$userBookId');
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref);
});
