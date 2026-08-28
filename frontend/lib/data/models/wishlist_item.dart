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

  /// Anunțul de pe care a fost apăsată inima. Favoritul e legat de EXEMPLAR,
  /// nu de titlu: aceeași carte listată de trei useri are trei inimi
  /// independente. null = dorință la nivel de titlu („vreau cartea, de la
  /// oricine") - așa vin rândurile din Book Match, iar inima lor se aprinde
  /// pe toate anunțurile titlului.
  final String? userBookId;
  final WishlistSource source;
  final DateTime createdAt;

  const WishlistItem({
    required this.id,
    required this.book,
    this.userBookId,
    this.source = WishlistSource.personal,
    required this.createdAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] as String,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      userBookId: json['userBookId'] as String?,
      source: WishlistSource.fromJson(json['source']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
