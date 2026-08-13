enum NotificationType {
  wishlistBookAvailable,
  exchangeRequestReceived,
  exchangeRequestAccepted,
  exchangeRequestRejected,
  exchangeMeetingScheduled,
  newMessage,
  priceOfferReceived,
  priceOfferAccepted,
  priceOfferRejected,
  followedUserNewBook,
  nearbyBookListed,
  interestBookListed,
  priceChanged,
  outbid,
  auctionWon,
  auctionEnded,
  exchangeMeetingProposed,
  exchangeMeetingAccepted,
  exchangeMeetingDeclined,
  exchangeContactShared,
  exchangeReady,
  exchangePostponed,
  exchangeDonePendingConfirmation,
  exchangeDoneDisputed,
  exchangeCompleted,
  exchangeCancelled,
  exchangeBookPending,
  exchangeReopened,

  /// Tip trimis de backend pe care versiunea asta de aplicație nu îl cunoaște.
  /// Notificarea se afișează cu textul primit de la server și fără acțiune la
  /// tap - important ca un backend mai nou să nu strice un client mai vechi.
  unknown,
}

extension NotificationTypeX on NotificationType {
  static NotificationType fromJson(String value) {
    switch (value) {
      case 'WISHLIST_BOOK_AVAILABLE':
        return NotificationType.wishlistBookAvailable;
      case 'EXCHANGE_REQUEST_RECEIVED':
        return NotificationType.exchangeRequestReceived;
      case 'EXCHANGE_REQUEST_ACCEPTED':
        return NotificationType.exchangeRequestAccepted;
      case 'EXCHANGE_REQUEST_REJECTED':
        return NotificationType.exchangeRequestRejected;
      case 'EXCHANGE_MEETING_SCHEDULED':
        return NotificationType.exchangeMeetingScheduled;
      case 'NEW_MESSAGE':
        return NotificationType.newMessage;
      case 'PRICE_OFFER_RECEIVED':
        return NotificationType.priceOfferReceived;
      case 'PRICE_OFFER_ACCEPTED':
        return NotificationType.priceOfferAccepted;
      case 'PRICE_OFFER_REJECTED':
        return NotificationType.priceOfferRejected;
      case 'FOLLOWED_USER_NEW_BOOK':
        return NotificationType.followedUserNewBook;
      case 'NEARBY_BOOK_LISTED':
        return NotificationType.nearbyBookListed;
      case 'INTEREST_BOOK_LISTED':
        return NotificationType.interestBookListed;
      case 'PRICE_CHANGED':
        return NotificationType.priceChanged;
      case 'OUTBID':
        return NotificationType.outbid;
      case 'AUCTION_WON':
        return NotificationType.auctionWon;
      case 'AUCTION_ENDED':
        return NotificationType.auctionEnded;
      case 'EXCHANGE_MEETING_PROPOSED':
        return NotificationType.exchangeMeetingProposed;
      case 'EXCHANGE_MEETING_ACCEPTED':
        return NotificationType.exchangeMeetingAccepted;
      case 'EXCHANGE_MEETING_DECLINED':
        return NotificationType.exchangeMeetingDeclined;
      case 'EXCHANGE_CONTACT_SHARED':
        return NotificationType.exchangeContactShared;
      case 'EXCHANGE_READY':
        return NotificationType.exchangeReady;
      case 'EXCHANGE_POSTPONED':
        return NotificationType.exchangePostponed;
      case 'EXCHANGE_DONE_PENDING_CONFIRMATION':
        return NotificationType.exchangeDonePendingConfirmation;
      case 'EXCHANGE_DONE_DISPUTED':
        return NotificationType.exchangeDoneDisputed;
      case 'EXCHANGE_COMPLETED':
        return NotificationType.exchangeCompleted;
      case 'EXCHANGE_CANCELLED':
        return NotificationType.exchangeCancelled;
      case 'EXCHANGE_BOOK_PENDING':
        return NotificationType.exchangeBookPending;
      case 'EXCHANGE_REOPENED':
        return NotificationType.exchangeReopened;
      default:
        // Deliberat NU aruncăm: un tip adăugat pe backend înaintea unui release
        // de aplicație ar face să crape întreaga listă de notificări, nu doar
        // rândul respectiv.
        return NotificationType.unknown;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationTypeX.fromJson(json['type'] as String),
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      message: message,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
