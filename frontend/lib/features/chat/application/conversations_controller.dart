import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/conversation.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';

/// Un singur controller servește și inbox-ul, și arhiva - `family` pe flag-ul
/// de arhivare, ca fiecare listă să se reîncarce independent.
class ConversationsController extends AsyncNotifier<List<Conversation>> {
  ConversationsController(this.archived);

  final bool archived;

  @override
  Future<List<Conversation>> build() async {
    final socketService = ref.read(chatSocketServiceProvider);
    await socketService.connect();
    socketService.onMessageNotification((_) => refresh());
    // Prezența schimbă doar bulina verde, deci se aplică pe starea deja
    // încărcată - un refetch la fiecare conectare a fiecărui partener de
    // discuție ar însemna zeci de cereri degeaba.
    socketService.onUserPresence(_applyPresence);
    ref.onDispose(() {
      socketService.offMessageNotification();
      socketService.offUserPresence();
    });

    return ref.read(chatRepositoryProvider).getConversations(archived: archived);
  }

  void _applyPresence(String userId, bool isOnline, DateTime? lastSeenAt) {
    final current = state.value;
    if (current == null) return;
    if (!current.any((conv) => conv.otherUser.id == userId)) return;

    state = AsyncValue.data([
      for (final conv in current)
        if (conv.otherUser.id == userId)
          Conversation(
            id: conv.id,
            otherUser: conv.otherUser
                .copyWithPresence(isOnline: isOnline, lastSeenAt: lastSeenAt),
            lastMessage: conv.lastMessage,
            updatedAt: conv.updatedAt,
            unreadCount: conv.unreadCount,
            isArchived: conv.isArchived,
          )
        else
          conv,
    ]);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(chatRepositoryProvider).getConversations(archived: archived),
    );
  }

  Future<void> setArchived(String conversationId, bool archived) async {
    await ref.read(chatRepositoryProvider).setArchived(conversationId, archived);
    // Conversația trece dintr-o listă în cealaltă, deci amândouă sunt stale.
    _refreshBothLists();
  }

  Future<void> delete(String conversationId) async {
    await ref.read(chatRepositoryProvider).deleteConversation(conversationId);
    _refreshBothLists();
  }

  void _refreshBothLists() {
    ref.invalidate(conversationsControllerProvider(false));
    ref.invalidate(conversationsControllerProvider(true));
  }
}

final conversationsControllerProvider =
    AsyncNotifierProvider.family<ConversationsController, List<Conversation>, bool>(
  ConversationsController.new,
);

/// Numărul total de mesaje necitite, pentru badge-ul din bara de navigare.
final unreadMessagesCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsControllerProvider(false));
  return conversations.maybeWhen(
    data: (list) => list.fold(0, (sum, conv) => sum + conv.unreadCount),
    orElse: () => 0,
  );
});
