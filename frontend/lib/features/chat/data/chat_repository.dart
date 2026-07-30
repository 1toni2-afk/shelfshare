import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';
import '../../../shared/utils/image_upload.dart';
import '../../safety/data/safety_repository.dart';

class ChatRepository {
  ChatRepository(this._ref);
  final Ref _ref;

  Future<List<Conversation>> getConversations({bool archived = false}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/conversations',
      queryParameters: {'archived': archived.toString()},
    );
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

  /// Căutare în conversația curentă - rezultatele vin cele mai noi întâi.
  Future<List<ChatMessage>> searchMessages(String conversationId, String query) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/conversations/$conversationId/messages/search',
      queryParameters: {'q': query},
    );
    return (response.data as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String conversationId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/conversations/$conversationId/read');
  }

  /// Ștergere doar pentru utilizatorul curent - celălalt își păstrează chatul.
  Future<void> deleteConversation(String conversationId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/conversations/$conversationId');
  }

  Future<void> setArchived(String conversationId, bool archived) async {
    final dio = _ref.read(apiClientProvider).dio;
    final path = '/conversations/$conversationId/archive';
    if (archived) {
      await dio.post(path);
    } else {
      await dio.delete(path);
    }
  }

  Future<void> reportConversation(
    String conversationId, {
    required ReportReason reason,
    String? details,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post(
      '/conversations/$conversationId/report',
      data: {'reason': reason.toJson(), 'details': ?details},
    );
  }

  Future<ChatMessage> sendPhoto(
    String conversationId, {
    required List<int> bytes,
    required String filename,
    String? replyToId,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final formData = FormData.fromMap({
      'photo': imageMultipartFile(bytes, filename),
      'replyToId': ?replyToId,
    });
    final response = await dio.post(
      '/conversations/$conversationId/photos',
      data: formData,
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref);
});
