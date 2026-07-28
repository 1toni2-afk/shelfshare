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
  /// Setat true când un exchange s-a completat pe această listare - carte
  /// „plecată permanent", nu mai poate fi făcută disponibilă. Vezi Milestone 10.
  final bool permanentlyTransferred;
  /// Setat când userul a apăsat delete pe carte - rămâne în coșul de gunoi
  /// 7 zile, iar apoi cron-ul o șterge definitiv.
  final DateTime? deletedAt;
  /// Descriere per exemplar (independent de Book.description care e a operei).
  /// Max 256 caractere pe backend. Milestone 10.
  final String? description;
  /// Tag-uri custom (max 5). Milestone 10.
  final List<String> tags;
  /// Localitatea unde se face schimbul (distinctă de user.city). Milestone 10.
  final String? city;

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
    this.permanentlyTransferred = false,
    this.deletedAt,
    this.description,
    this.tags = const [],
    this.city,
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
      permanentlyTransferred: json['permanentlyTransferred'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      city: json['city'] as String?,
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
