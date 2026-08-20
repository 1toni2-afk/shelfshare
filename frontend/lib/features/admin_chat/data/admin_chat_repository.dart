import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';

class AdminChatMessage {
  final String id;
  final String senderId;
  final bool isFromAdmin;
  final String content;
  final DateTime createdAt;

  const AdminChatMessage({
    required this.id,
    required this.senderId,
    required this.isFromAdmin,
    required this.content,
    required this.createdAt,
  });

  factory AdminChatMessage.fromJson(Map<String, dynamic> json) {
    return AdminChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      isFromAdmin: json['isFromAdmin'] as bool? ?? false,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AdminChatConversation {
  final String id;
  final List<AdminChatMessage> messages;
  final String? userName;
  final String? userEmail;

  const AdminChatConversation({
    required this.id,
    required this.messages,
    this.userName,
    this.userEmail,
  });

  factory AdminChatConversation.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return AdminChatConversation(
      id: json['id'] as String,
      messages: (json['messages'] as List)
          .map((e) => AdminChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      userName: user?['name'] as String?,
      userEmail: user?['email'] as String?,
    );
  }
}

/// O conversație din inbox-ul de admin - user-ul care a scris, plus ultimul
/// mesaj, ca listă (fără istoricul complet, încărcat separat la deschidere).
class AdminChatSummary {
  final String id;
  final String userId;
  final String? userName;
  final String userEmail;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final bool hasUnread;

  const AdminChatSummary({
    required this.id,
    required this.userId,
    this.userName,
    required this.userEmail,
    this.lastMessageContent,
    this.lastMessageAt,
    required this.hasUnread,
  });

  factory AdminChatSummary.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final lastMessage = json['lastMessage'] as Map<String, dynamic>?;
    return AdminChatSummary(
      id: json['id'] as String,
      userId: user['id'] as String,
      userName: user['name'] as String?,
      userEmail: user['email'] as String,
      lastMessageContent: lastMessage?['content'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      hasUnread: json['hasUnread'] as bool? ?? false,
    );
  }
}

/// „Chat with an admin" - vezi backend/src/admin-chat pentru model. Userul
/// obișnuit are o singură conversație cu echipa de admini (getMyConversation);
/// orice admin poate vedea/răspunde la toate conversațiile (getAllConversations).
class AdminChatRepository {
  AdminChatRepository(this._ref);
  final Ref _ref;

  Future<AdminChatConversation> getMyConversation() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin-chat/me');
    return AdminChatConversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> sendMyMessage(String content) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/admin-chat/me/messages', data: {'content': content});
  }

  Future<void> markMyConversationRead() async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/admin-chat/me/read');
  }

  Future<List<AdminChatSummary>> getAllConversations() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin-chat/conversations');
    return (response.data as List)
        .map((e) => AdminChatSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminChatConversation> getConversationMessages(String conversationId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin-chat/conversations/$conversationId/messages');
    return AdminChatConversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> sendAdminReply(String conversationId, String content) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/admin-chat/conversations/$conversationId/messages', data: {'content': content});
  }

  Future<void> markConversationReadByAdmin(String conversationId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/admin-chat/conversations/$conversationId/read');
  }
}

final adminChatRepositoryProvider = Provider<AdminChatRepository>((ref) {
  return AdminChatRepository(ref);
});
