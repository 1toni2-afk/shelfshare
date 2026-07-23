import 'book.dart';
import 'user.dart';

/// Exemplarul concret al unei cărți deținut de un utilizator - starea
/// fizică, pozele reale, disponibilitatea pentru schimb.
class UserBook {
  final String id;
  final String userId;
  final Book book;
  final PublicUser? owner; // prezent doar în /books/browse
  final BookCondition condition;
  final String? language;
  final String? edition;
  final bool isHardcover;
  final bool availableForSwap;
  final bool isForSale;
  final double? salePrice;
  final bool isNegotiable;
  final bool isAuction;
  final AuctionCardSummary? auction;
  final bool isPromoted;
  final int viewCount;
  final double? distanceKm;
  final List<String> photos;
  final DateTime createdAt;

  const UserBook({
    required this.id,
    required this.userId,
    required this.book,
    this.owner,
    required this.condition,
    this.language,
    this.edition,
    this.isHardcover = false,
    this.availableForSwap = true,
    this.isForSale = false,
    this.salePrice,
    this.isNegotiable = true,
    this.isAuction = false,
    this.auction,
    this.isPromoted = false,
    this.viewCount = 0,
    this.distanceKm,
    this.photos = const [],
    required this.createdAt,
  });

  factory UserBook.fromJson(Map<String, dynamic> json) {
    return UserBook(
      id: json['id'] as String,
      userId: json['userId'] as String,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      owner: json['user'] != null
          ? PublicUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      condition: BookConditionX.fromJson(json['condition'] as String),
      language: json['language'] as String?,
      edition: json['edition'] as String?,
      isHardcover: json['isHardcover'] as bool? ?? false,
      availableForSwap: json['availableForSwap'] as bool? ?? true,
      isForSale: json['isForSale'] as bool? ?? false,
      salePrice: json['salePrice'] != null
          ? double.parse(json['salePrice'].toString())
          : null,
      isNegotiable: json['isNegotiable'] as bool? ?? true,
      isAuction: json['isAuction'] as bool? ?? false,
      auction: json['auction'] != null
          ? AuctionCardSummary.fromJson(json['auction'] as Map<String, dynamic>)
          : null,
      isPromoted: json['isPromoted'] as bool? ?? false,
      viewCount: json['viewCount'] as int? ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Rezumatul licitației afișat pe cardul din browse/library - fără istoricul
/// de oferte, doar cât să arate prețul curent și timpul rămas.
class AuctionCardSummary {
  final String id;
  final double currentPrice;
  final DateTime endsAt;
  final String status;
  final double? buyNowPrice;

  const AuctionCardSummary({
    required this.id,
    required this.currentPrice,
    required this.endsAt,
    required this.status,
    this.buyNowPrice,
  });

  factory AuctionCardSummary.fromJson(Map<String, dynamic> json) {
    return AuctionCardSummary(
      id: json['id'] as String,
      currentPrice: double.parse(json['currentPrice'].toString()),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: json['status'] as String,
      buyNowPrice: json['buyNowPrice'] != null
          ? double.parse(json['buyNowPrice'].toString())
          : null,
    );
  }
}
