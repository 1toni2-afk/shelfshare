import 'user.dart';
import 'message.dart';

class Conversation {
  final String id;
  final PublicUser otherUser;
  final ChatMessage? lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      otherUser: PublicUser.fromJson(json['otherUser'] as Map<String, dynamic>),
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
