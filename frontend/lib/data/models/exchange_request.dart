import '../../l10n/app_localizations.dart';
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

  /// Vezi nota din OfferStatusX.label - aceeași problemă de i18n.
  String label(AppLocalizations l10n) {
    switch (this) {
      case ExchangeStatus.pending:
        return l10n.exchangeStatusPending;
      case ExchangeStatus.accepted:
        return l10n.exchangeStatusAccepted;
      case ExchangeStatus.rejected:
        return l10n.exchangeStatusRejected;
      case ExchangeStatus.cancelled:
        return l10n.exchangeStatusCancelled;
      case ExchangeStatus.completed:
        return l10n.exchangeStatusCompleted;
      case ExchangeStatus.expired:
        return l10n.exchangeStatusExpired;
    }
  }
}

class ExchangeRequest {
  final String id;
  final String requesterId;
  final String ownerId;
  final UserBook requestedBook;
  final UserBook? offeredBook;
  /// Cărți suplimentare oferite în același pachet (feature backlog #17),
  /// dincolo de `offeredBook` (prima/principala carte oferită).
  final List<UserBook> additionalOfferedBooks;
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

  // Exchange flow v2
  final String? meetingProposedBy;
  final DateTime? meetingAcceptedAt;
  final DateTime? acceptedAt;
  final String? requesterContactPhone;
  final String? ownerContactPhone;
  final DateTime? requesterContactSharedAt;
  final DateTime? ownerContactSharedAt;
  final DateTime? requesterSafetyAckAt;
  final DateTime? ownerSafetyAckAt;
  final List<String> requesterConditionPhotos;
  final List<String> ownerConditionPhotos;
  final DateTime? requesterDoneAt;
  final DateTime? ownerDoneAt;
  final String? cancelReason;
  final String? cancelDetails;
  final String? cancelledBy;

  const ExchangeRequest({
    required this.id,
    required this.requesterId,
    required this.ownerId,
    required this.requestedBook,
    this.offeredBook,
    this.additionalOfferedBooks = const [],
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
    this.meetingProposedBy,
    this.meetingAcceptedAt,
    this.acceptedAt,
    this.requesterContactPhone,
    this.ownerContactPhone,
    this.requesterContactSharedAt,
    this.ownerContactSharedAt,
    this.requesterSafetyAckAt,
    this.ownerSafetyAckAt,
    this.requesterConditionPhotos = const [],
    this.ownerConditionPhotos = const [],
    this.requesterDoneAt,
    this.ownerDoneAt,
    this.cancelReason,
    this.cancelDetails,
    this.cancelledBy,
  });

  bool isRequester(String myUserId) => myUserId == requesterId;

  /// Rating-ul dat de mine celuilalt participant, dacă `myUserId` a
  /// evaluat deja acest schimb - folosit ca să știm dacă mai arătăm
  /// butonul de evaluare sau nu.
  bool myRatingGiven(String myUserId) {
    if (myUserId == requesterId) return requesterRatingForOwner != null;
    if (myUserId == ownerId) return ownerRatingForRequester != null;
    return false;
  }

  /// Există o oră propusă care încă așteaptă răspunsul (accept/decline) al
  /// celeilalte părți - eu sunt cel care trebuie să răspundă.
  bool meetingAwaitsMyResponse(String myUserId) =>
      meetingTime != null &&
      meetingAcceptedAt == null &&
      meetingProposedBy != null &&
      meetingProposedBy != myUserId;

  /// Eu am propus ora și aștept confirmarea celeilalte părți.
  bool meetingAwaitsOtherResponse(String myUserId) =>
      meetingTime != null && meetingAcceptedAt == null && meetingProposedBy == myUserId;

  bool get isMeetingConfirmed => meetingTime != null && meetingAcceptedAt != null;

  bool myContactShared(String myUserId) =>
      isRequester(myUserId) ? requesterContactSharedAt != null : ownerContactSharedAt != null;

  bool otherContactShared(String myUserId) =>
      isRequester(myUserId) ? ownerContactSharedAt != null : requesterContactSharedAt != null;

  /// Telefonul celeilalte părți, dacă l-a partajat - null dacă nu, caz în
  /// care UI-ul cade mereu pe fallback-ul "Message in app".
  String? otherContactPhone(String myUserId) =>
      isRequester(myUserId) ? ownerContactPhone : requesterContactPhone;

  /// Telefonul pe care l-am partajat eu însumi - folosit ca să pre-completăm
  /// câmpul când userul apasă "Edit details".
  String? myContactPhone(String myUserId) =>
      isRequester(myUserId) ? requesterContactPhone : ownerContactPhone;

  bool mySafetyAck(String myUserId) =>
      isRequester(myUserId) ? requesterSafetyAckAt != null : ownerSafetyAckAt != null;

  bool otherSafetyAck(String myUserId) =>
      isRequester(myUserId) ? ownerSafetyAckAt != null : requesterSafetyAckAt != null;

  /// Pozele urcate de MINE cu starea cărții - vezi feature backlog #14.
  List<String> myConditionPhotos(String myUserId) =>
      isRequester(myUserId) ? requesterConditionPhotos : ownerConditionPhotos;

  /// Pozele urcate de cealaltă parte.
  List<String> otherConditionPhotos(String myUserId) =>
      isRequester(myUserId) ? ownerConditionPhotos : requesterConditionPhotos;

  bool get isReadyToExchange =>
      status == ExchangeStatus.accepted &&
      isMeetingConfirmed &&
      requesterSafetyAckAt != null &&
      ownerSafetyAckAt != null;

  bool myDone(String myUserId) =>
      isRequester(myUserId) ? requesterDoneAt != null : ownerDoneAt != null;

  bool otherDone(String myUserId) =>
      isRequester(myUserId) ? ownerDoneAt != null : requesterDoneAt != null;

  /// Eu am apăsat Done și aștept ca cealaltă parte să confirme sau să conteste.
  bool isAwaitingOtherConfirmation(String myUserId) => myDone(myUserId) && !otherDone(myUserId);

  /// Cealaltă parte a apăsat Done - eu trebuie să confirm sau să contest.
  bool isAwaitingMyConfirmation(String myUserId) => otherDone(myUserId) && !myDone(myUserId);

  factory ExchangeRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) =>
        json[key] != null ? DateTime.parse(json[key] as String) : null;

    return ExchangeRequest(
      id: json['id'] as String,
      requesterId: json['requesterId'] as String,
      ownerId: json['ownerId'] as String,
      requestedBook:
          UserBook.fromJson(json['requestedBook'] as Map<String, dynamic>),
      offeredBook: json['offeredBook'] != null
          ? UserBook.fromJson(json['offeredBook'] as Map<String, dynamic>)
          : null,
      additionalOfferedBooks: (json['additionalOfferedBooks'] as List?)
              ?.map((e) => UserBook.fromJson(
                  (e as Map<String, dynamic>)['userBook'] as Map<String, dynamic>))
              .toList() ??
          const [],
      offeredAmount: (json['offeredAmount'] as num?)?.toDouble(),
      status: ExchangeStatusX.fromJson(json['status'] as String),
      message: json['message'] as String?,
      requester: PublicUser.fromJson(json['requester'] as Map<String, dynamic>),
      owner: PublicUser.fromJson(json['owner'] as Map<String, dynamic>),
      meetingTime: parseDate('meetingTime'),
      meetingLocation: json['meetingLocation'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      requesterRatingForOwner: json['requesterRatingForOwner'] as int?,
      ownerRatingForRequester: json['ownerRatingForRequester'] as int?,
      meetingProposedBy: json['meetingProposedBy'] as String?,
      meetingAcceptedAt: parseDate('meetingAcceptedAt'),
      acceptedAt: parseDate('acceptedAt'),
      requesterContactPhone: json['requesterContactPhone'] as String?,
      ownerContactPhone: json['ownerContactPhone'] as String?,
      requesterContactSharedAt: parseDate('requesterContactSharedAt'),
      ownerContactSharedAt: parseDate('ownerContactSharedAt'),
      requesterSafetyAckAt: parseDate('requesterSafetyAckAt'),
      ownerSafetyAckAt: parseDate('ownerSafetyAckAt'),
      requesterConditionPhotos:
          (json['requesterConditionPhotos'] as List?)?.cast<String>() ?? const [],
      ownerConditionPhotos: (json['ownerConditionPhotos'] as List?)?.cast<String>() ?? const [],
      requesterDoneAt: parseDate('requesterDoneAt'),
      ownerDoneAt: parseDate('ownerDoneAt'),
      cancelReason: json['cancelReason'] as String?,
      cancelDetails: json['cancelDetails'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
    );
  }
}
