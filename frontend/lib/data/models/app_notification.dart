enum NotificationType {
  wishlistBookAvailable,
  exchangeRequestReceived,
  exchangeRequestAccepted,
  exchangeRequestRejected,
  newMessage,
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
      case 'NEW_MESSAGE':
        return NotificationType.newMessage;
      default:
        throw ArgumentError('Tip necunoscut: $value');
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
}
