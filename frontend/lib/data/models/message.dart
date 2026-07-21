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
    this.isRead = false,
    required this.createdAt,
  });

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
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
