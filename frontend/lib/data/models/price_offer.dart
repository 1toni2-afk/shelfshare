import '../../l10n/app_localizations.dart';
import 'book.dart';
import 'user.dart';
import 'user_book.dart';

enum OfferStatus { pending, accepted, rejected, cancelled, expired, completed }

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
      case 'EXPIRED':
        return OfferStatus.expired;
      case 'COMPLETED':
        return OfferStatus.completed;
      default:
        throw ArgumentError('Status necunoscut: $value');
    }
  }

  /// Eticheta afișată în UI. Era hardcodată în română, deci pe interfața EN/DE/HU
  /// ieșea un „În așteptare" în mijlocul textului tradus - acum trece prin l10n.
  String label(AppLocalizations l10n) {
    switch (this) {
      case OfferStatus.pending:
        return l10n.offerStatusPending;
      case OfferStatus.accepted:
        return l10n.offerStatusAccepted;
      case OfferStatus.rejected:
        return l10n.offerStatusRejected;
      case OfferStatus.cancelled:
        return l10n.offerStatusCancelled;
      case OfferStatus.expired:
        return l10n.offerStatusExpired;
      case OfferStatus.completed:
        return l10n.offerStatusCompleted;
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

  // Sale flow v2 - mirror exact al câmpurilor de pe ExchangeRequest.
  final DateTime? acceptedAt;
  final DateTime? meetingTime;
  final String? meetingLocation;
  final String? meetingProposedBy;
  final DateTime? meetingAcceptedAt;
  final String? buyerContactPhone;
  final String? ownerContactPhone;
  final DateTime? buyerContactSharedAt;
  final DateTime? ownerContactSharedAt;
  final DateTime? buyerSafetyAckAt;
  final DateTime? ownerSafetyAckAt;
  final DateTime? buyerDoneAt;
  final DateTime? ownerDoneAt;
  final String? cancelReason;
  final String? cancelDetails;
  final String? cancelledBy;

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
    this.acceptedAt,
    this.meetingTime,
    this.meetingLocation,
    this.meetingProposedBy,
    this.meetingAcceptedAt,
    this.buyerContactPhone,
    this.ownerContactPhone,
    this.buyerContactSharedAt,
    this.ownerContactSharedAt,
    this.buyerSafetyAckAt,
    this.ownerSafetyAckAt,
    this.buyerDoneAt,
    this.ownerDoneAt,
    this.cancelReason,
    this.cancelDetails,
    this.cancelledBy,
  });

  bool isBuyer(String myUserId) => myUserId == buyerId;

  bool meetingAwaitsMyResponse(String myUserId) =>
      meetingTime != null &&
      meetingAcceptedAt == null &&
      meetingProposedBy != null &&
      meetingProposedBy != myUserId;

  bool meetingAwaitsOtherResponse(String myUserId) =>
      meetingTime != null && meetingAcceptedAt == null && meetingProposedBy == myUserId;

  bool get isMeetingConfirmed => meetingTime != null && meetingAcceptedAt != null;

  bool myContactShared(String myUserId) =>
      isBuyer(myUserId) ? buyerContactSharedAt != null : ownerContactSharedAt != null;

  bool otherContactShared(String myUserId) =>
      isBuyer(myUserId) ? ownerContactSharedAt != null : buyerContactSharedAt != null;

  String? otherContactPhone(String myUserId) =>
      isBuyer(myUserId) ? ownerContactPhone : buyerContactPhone;

  String? myContactPhone(String myUserId) =>
      isBuyer(myUserId) ? buyerContactPhone : ownerContactPhone;

  bool mySafetyAck(String myUserId) =>
      isBuyer(myUserId) ? buyerSafetyAckAt != null : ownerSafetyAckAt != null;

  bool otherSafetyAck(String myUserId) =>
      isBuyer(myUserId) ? ownerSafetyAckAt != null : buyerSafetyAckAt != null;

  bool myDone(String myUserId) => isBuyer(myUserId) ? buyerDoneAt != null : ownerDoneAt != null;

  bool otherDone(String myUserId) => isBuyer(myUserId) ? ownerDoneAt != null : buyerDoneAt != null;

  bool isAwaitingOtherConfirmation(String myUserId) => myDone(myUserId) && !otherDone(myUserId);

  bool isAwaitingMyConfirmation(String myUserId) => otherDone(myUserId) && !myDone(myUserId);

  factory PriceOffer.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) =>
        json[key] != null ? DateTime.parse(json[key] as String) : null;

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
      acceptedAt: parseDate('acceptedAt'),
      meetingTime: parseDate('meetingTime'),
      meetingLocation: json['meetingLocation'] as String?,
      meetingProposedBy: json['meetingProposedBy'] as String?,
      meetingAcceptedAt: parseDate('meetingAcceptedAt'),
      buyerContactPhone: json['buyerContactPhone'] as String?,
      ownerContactPhone: json['ownerContactPhone'] as String?,
      buyerContactSharedAt: parseDate('buyerContactSharedAt'),
      ownerContactSharedAt: parseDate('ownerContactSharedAt'),
      buyerSafetyAckAt: parseDate('buyerSafetyAckAt'),
      ownerSafetyAckAt: parseDate('ownerSafetyAckAt'),
      buyerDoneAt: parseDate('buyerDoneAt'),
      ownerDoneAt: parseDate('ownerDoneAt'),
      cancelReason: json['cancelReason'] as String?,
      cancelDetails: json['cancelDetails'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
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
