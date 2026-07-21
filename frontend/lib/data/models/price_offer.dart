import 'book.dart';
import 'user.dart';
import 'user_book.dart';

enum OfferStatus { pending, accepted, rejected, cancelled }

extension OfferStatusX on OfferStatus {
  static OfferStatus fromJson(String value) {
    switch (value) {
      case 'PENDING':
        return OfferStatus.pending;
      case 'ACCEPTED':
        return OfferStatus.accepted;
      case 'REJECTED':
        return OfferStatus.rejected;
      case 'CANCELLED':
        return OfferStatus.cancelled;
      default:
        throw ArgumentError('Status necunoscut: $value');
    }
  }

  String get label {
    switch (this) {
      case OfferStatus.pending:
        return 'În așteptare';
      case OfferStatus.accepted:
        return 'Acceptată';
      case OfferStatus.rejected:
        return 'Respinsă';
      case OfferStatus.cancelled:
        return 'Anulată';
    }
  }
}

class PriceOffer {
  final String id;
  final String buyerId;
  final String ownerId;
  final UserBook userBook;
  final double amount;
  final String? message;
  final OfferStatus status;
  final PublicUser buyer;
  final PublicUser owner;
  final DateTime createdAt;

  const PriceOffer({
    required this.id,
    required this.buyerId,
    required this.ownerId,
    required this.userBook,
    required this.amount,
    this.message,
    required this.status,
    required this.buyer,
    required this.owner,
    required this.createdAt,
  });

  factory PriceOffer.fromJson(Map<String, dynamic> json) {
    return PriceOffer(
      id: json['id'] as String,
      buyerId: json['buyerId'] as String,
      ownerId: json['ownerId'] as String,
      userBook: UserBook.fromJson(json['userBook'] as Map<String, dynamic>),
      amount: double.parse(json['amount'].toString()),
      message: json['message'] as String?,
      status: OfferStatusX.fromJson(json['status'] as String),
      buyer: PublicUser.fromJson(json['buyer'] as Map<String, dynamic>),
      owner: PublicUser.fromJson(json['owner'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// O verigă din lanțul de proveniență al unei cărți - un anunț separat,
/// cu proprietarul, starea și pozele declarate chiar de el la momentul
/// respectiv. `transferredAt`/`transferType` sunt null dacă veriga e încă
/// activă (nu a fost încă schimbată/vândută mai departe).
class ListingHistoryEntry {
  final String userBookId;
  final bool isCurrent;
  final String ownerId;
  final String? ownerName;
  final BookCondition condition;
  final List<String> photos;
  final DateTime listedAt;
  final DateTime? transferredAt;
  final String? transferType;

  const ListingHistoryEntry({
    required this.userBookId,
    required this.isCurrent,
    required this.ownerId,
    this.ownerName,
    required this.condition,
    this.photos = const [],
    required this.listedAt,
    this.transferredAt,
    this.transferType,
  });

  factory ListingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ListingHistoryEntry(
      userBookId: json['userBookId'] as String,
      isCurrent: json['isCurrent'] as bool,
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String?,
      condition: BookConditionX.fromJson(json['condition'] as String),
      photos: (json['photos'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      listedAt: DateTime.parse(json['listedAt'] as String),
      transferredAt:
          json['transferredAt'] != null ? DateTime.parse(json['transferredAt'] as String) : null,
      transferType: json['transferType'] as String?,
    );
  }
}
