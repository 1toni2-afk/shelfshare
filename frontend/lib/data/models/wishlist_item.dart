import 'book.dart';

/// De unde a ajuns titlul pe wishlist (oglindește enum-ul `WishlistItemSource`
/// din Prisma). `personal` = adăugat manual (inima), `bookMatch` = dintr-un
/// „Yes" în Book Match. Valorile necunoscute cad pe `personal`, ca un enum nou
/// pe backend să nu arunce la parsare.
enum WishlistSource {
  personal,
  bookMatch;

  static WishlistSource fromJson(Object? value) =>
      value == 'BOOK_MATCH' ? WishlistSource.bookMatch : WishlistSource.personal;
}

class WishlistItem {
  final String id;
  final Book book;
  final WishlistSource source;
  final DateTime createdAt;

  const WishlistItem({
    required this.id,
    required this.book,
    this.source = WishlistSource.personal,
    required this.createdAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] as String,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      source: WishlistSource.fromJson(json['source']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
