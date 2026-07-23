import 'user.dart';
import 'user_book.dart';

enum ExchangeStatus { pending, accepted, rejected, cancelled, completed, expired }

extension ExchangeStatusX on ExchangeStatus {
  static ExchangeStatus fromJson(String value) {
    switch (value) {
      case 'PENDING':
        return ExchangeStatus.pending;
      case 'ACCEPTED':
        return ExchangeStatus.accepted;
      case 'REJECTED':
        return ExchangeStatus.rejected;
      case 'CANCELLED':
        return ExchangeStatus.cancelled;
      case 'COMPLETED':
        return ExchangeStatus.completed;
      case 'EXPIRED':
        return ExchangeStatus.expired;
      default:
        throw ArgumentError('Status necunoscut: $value');
    }
  }

  String get label {
    switch (this) {
      case ExchangeStatus.pending:
        return 'În așteptare';
      case ExchangeStatus.accepted:
        return 'Acceptat';
      case ExchangeStatus.rejected:
        return 'Respins';
      case ExchangeStatus.cancelled:
        return 'Anulat';
      case ExchangeStatus.completed:
        return 'Finalizat';
      case ExchangeStatus.expired:
        return 'Expirat';
    }
  }
}

class ExchangeRequest {
  final String id;
  final String requesterId;
  final String ownerId;
  final UserBook requestedBook;
  final UserBook? offeredBook;
  final double? offeredAmount;
  final ExchangeStatus status;
  final String? message;
  final PublicUser requester;
  final PublicUser owner;
  final DateTime? meetingTime;
  final String? meetingLocation;
  final DateTime createdAt;
  final int? requesterRatingForOwner;
  final int? ownerRatingForRequester;

  const ExchangeRequest({
    required this.id,
    required this.requesterId,
    required this.ownerId,
    required this.requestedBook,
    this.offeredBook,
    this.offeredAmount,
    required this.status,
    this.message,
    required this.requester,
    required this.owner,
    this.meetingTime,
    this.meetingLocation,
    required this.createdAt,
    this.requesterRatingForOwner,
    this.ownerRatingForRequester,
  });

  /// Rating-ul dat de mine celuilalt participant, dacă `myUserId` a
  /// evaluat deja acest schimb - folosit ca să știm dacă mai arătăm
  /// butonul de evaluare sau nu.
  bool myRatingGiven(String myUserId) {
    if (myUserId == requesterId) return requesterRatingForOwner != null;
    if (myUserId == ownerId) return ownerRatingForRequester != null;
    return false;
  }

  factory ExchangeRequest.fromJson(Map<String, dynamic> json) {
    return ExchangeRequest(
      id: json['id'] as String,
      requesterId: json['requesterId'] as String,
      ownerId: json['ownerId'] as String,
      requestedBook:
          UserBook.fromJson(json['requestedBook'] as Map<String, dynamic>),
      offeredBook: json['offeredBook'] != null
          ? UserBook.fromJson(json['offeredBook'] as Map<String, dynamic>)
          : null,
      offeredAmount: (json['offeredAmount'] as num?)?.toDouble(),
      status: ExchangeStatusX.fromJson(json['status'] as String),
      message: json['message'] as String?,
      requester: PublicUser.fromJson(json['requester'] as Map<String, dynamic>),
      owner: PublicUser.fromJson(json['owner'] as Map<String, dynamic>),
      meetingTime: json['meetingTime'] != null
          ? DateTime.parse(json['meetingTime'] as String)
          : null,
      meetingLocation: json['meetingLocation'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      requesterRatingForOwner: json['requesterRatingForOwner'] as int?,
      ownerRatingForRequester: json['ownerRatingForRequester'] as int?,
    );
  }
}
