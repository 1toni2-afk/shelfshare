import 'user_book.dart';

/// Identitatea ofertantului - anonimizată pentru ceilalți licitatori ("Ofertant
/// #N", doar `label`) dar completă pentru vânzător (name/username/poză).
class AuctionBidder {
  final String? id;
  final String? name;
  final String? username;
  final String? profileImage;
  final String? label;

  const AuctionBidder({this.id, this.name, this.username, this.profileImage, this.label});

  factory AuctionBidder.fromJson(Map<String, dynamic> json) {
    return AuctionBidder(
      id: json['id'] as String?,
      name: json['name'] as String?,
      username: json['username'] as String?,
      profileImage: json['profileImage'] as String?,
      label: json['label'] as String?,
    );
  }

  String displayName(String fallback) => label ?? name ?? username ?? fallback;
}

class AuctionBid {
  final String id;
  final double amount;
  final DateTime createdAt;
  final AuctionBidder bidder;

  const AuctionBid({
    required this.id,
    required this.amount,
    required this.createdAt,
    required this.bidder,
  });

  factory AuctionBid.fromJson(Map<String, dynamic> json) {
    return AuctionBid(
      id: json['id'] as String,
      amount: double.parse(json['amount'].toString()),
      createdAt: DateTime.parse(json['createdAt'] as String),
      bidder: AuctionBidder.fromJson(json['bidder'] as Map<String, dynamic>),
    );
  }
}

class Auction {
  final String id;
  final double startingPrice;
  final double? reservePrice;
  final double? buyNowPrice;
  final double currentPrice;
  final DateTime endsAt;
  final String status;
  final DateTime createdAt;
  final bool reserveMet;
  final int watchersCount;
  final AuctionBidder? highestBidder;
  final UserBook userBook;
  final List<AuctionBid> bids;
  final bool isSeller;
  final bool isWatching;
  final bool canBuyNow;

  const Auction({
    required this.id,
    required this.startingPrice,
    this.reservePrice,
    this.buyNowPrice,
    required this.currentPrice,
    required this.endsAt,
    required this.status,
    required this.createdAt,
    required this.reserveMet,
    required this.watchersCount,
    this.highestBidder,
    required this.userBook,
    required this.bids,
    required this.isSeller,
    required this.isWatching,
    required this.canBuyNow,
  });

  bool get hasEnded => status != 'ACTIVE' || endsAt.isBefore(DateTime.now());

  factory Auction.fromJson(Map<String, dynamic> json) {
    return Auction(
      id: json['id'] as String,
      startingPrice: double.parse(json['startingPrice'].toString()),
      reservePrice: json['reservePrice'] != null
          ? double.parse(json['reservePrice'].toString())
          : null,
      buyNowPrice: json['buyNowPrice'] != null
          ? double.parse(json['buyNowPrice'].toString())
          : null,
      currentPrice: double.parse(json['currentPrice'].toString()),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reserveMet: json['reserveMet'] as bool? ?? true,
      watchersCount: json['watchersCount'] as int? ?? 0,
      highestBidder: json['highestBidder'] != null
          ? AuctionBidder.fromJson(json['highestBidder'] as Map<String, dynamic>)
          : null,
      userBook: UserBook.fromJson(json['userBook'] as Map<String, dynamic>),
      bids: (json['bids'] as List<dynamic>? ?? [])
          .map((e) => AuctionBid.fromJson(e as Map<String, dynamic>))
          .toList(),
      isSeller: json['isSeller'] as bool? ?? false,
      isWatching: json['isWatching'] as bool? ?? false,
      canBuyNow: json['canBuyNow'] as bool? ?? false,
    );
  }
}
