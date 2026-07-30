class PriceOfferSummary {
  final String id;
  final double amount;
  final String status;
  final String bookTitle;
  final String? bookCoverUrl;

  const PriceOfferSummary({
    required this.id,
    required this.amount,
    required this.status,
    required this.bookTitle,
    this.bookCoverUrl,
  });

  factory PriceOfferSummary.fromJson(Map<String, dynamic> json) {
    final userBook = json['userBook'] as Map<String, dynamic>;
    final book = userBook['book'] as Map<String, dynamic>;
    return PriceOfferSummary(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      bookTitle: book['title'] as String,
      bookCoverUrl: book['coverUrl'] as String?,
    );
  }
}

/// Citatul afișat deasupra unui răspuns. Doar atât cât să se recunoască
/// mesajul, nu toată încărcătura lui (vezi REPLY_TO_SELECT în backend).
class ReplyPreview {
  final String id;
  final String senderId;
  final String? content;
  final String? photo;
  final String? location;

  const ReplyPreview({
    required this.id,
    required this.senderId,
    this.content,
    this.photo,
    this.location,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String?,
      photo: json['photo'] as String?,
      location: json['location'] as String?,
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final String? photo;
  final String? location;
  final double? locationLat;
  final double? locationLng;
  final DateTime? meetingAt;
  final PriceOfferSummary? priceOffer;
  final ReplyPreview? replyTo;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.photo,
    this.location,
    this.locationLat,
    this.locationLng,
    this.meetingAt,
    this.priceOffer,
    this.replyTo,
    this.isRead = false,
    required this.createdAt,
  });

  ChatMessage copyWith({PriceOfferSummary? priceOffer, bool? isRead}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      photo: photo,
      location: location,
      locationLat: locationLat,
      locationLng: locationLng,
      meetingAt: meetingAt,
      priceOffer: priceOffer ?? this.priceOffer,
      replyTo: replyTo,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String?,
      photo: json['photo'] as String?,
      location: json['location'] as String?,
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
      meetingAt: json['meetingAt'] != null ? DateTime.parse(json['meetingAt'] as String) : null,
      priceOffer: json['priceOffer'] != null
          ? PriceOfferSummary.fromJson(json['priceOffer'] as Map<String, dynamic>)
          : null,
      replyTo: json['replyTo'] != null
          ? ReplyPreview.fromJson(json['replyTo'] as Map<String, dynamic>)
          : null,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
