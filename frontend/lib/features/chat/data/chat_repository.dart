import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';

class ChatRepository {
  ChatRepository(this._ref);
  final Ref _ref;

  Future<List<Conversation>> getConversations() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/conversations');
    return (response.data as List<dynamic>)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> startConversation(String otherUserId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/conversations', data: {'otherUserId': otherUserId});
    return Conversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getMessages(String conversationId, {String? before}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {'before': ?before},
    );
    return (response.data as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String conversationId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/conversations/$conversationId/read');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref);
});
