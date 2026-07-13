import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/conversation.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';

class ConversationsController extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final socketService = ref.read(chatSocketServiceProvider);
    await socketService.connect();
    socketService.onMessageNotification((_) => refresh());
    ref.onDispose(socketService.offMessageNotification);

    return ref.read(chatRepositoryProvider).getConversations();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(chatRepositoryProvider).getConversations());
  }
}

final conversationsControllerProvider =
    AsyncNotifierProvider<ConversationsController, List<Conversation>>(
  ConversationsController.new,
);
