import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/message.dart';
import '../../../data/models/user.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/chat_controller.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId, this.otherUser});
  final String conversationId;
  final PublicUser? otherUser;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    ref.read(chatControllerProvider(widget.conversationId).notifier).sendMessage(text);
    _messageController.clear();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.conversationId));
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;

    ref.listen(chatControllerProvider(widget.conversationId), (previous, next) {
      final previousLastId = previous?.messages.isNotEmpty == true ? previous!.messages.last.id : null;
      final nextLastId = next.messages.isNotEmpty ? next.messages.last.id : null;
      if (nextLastId != null && nextLastId != previousLastId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUser?.name ?? 'Conversație')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                      ? Center(child: Text(state.error!))
                      : _MessageList(
                          messages: state.messages,
                          currentUserId: currentUserId,
                          scrollController: _scrollController,
                          isLoadingMore: state.isLoadingMore,
                          hasMore: state.hasMore,
                          onLoadMore: () =>
                              ref.read(chatControllerProvider(widget.conversationId).notifier).loadMore(),
                        ),
            ),
            if (state.otherUserTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'scrie...',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: (_) =>
                          ref.read(chatControllerProvider(widget.conversationId).notifier).notifyTyping(),
                      decoration: const InputDecoration(hintText: 'Scrie un mesaj...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<ChatMessage> messages;
  final String? currentUserId;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('Niciun mesaj încă. Spune salut!'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore && !isLoadingMore && notification.metrics.pixels <= 100) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: messages.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (isLoadingMore && index == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final messageIndex = isLoadingMore ? index - 1 : index;
          final message = messages[messageIndex];
          final isMine = message.senderId == currentUserId;
          return Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _MessageContent(message: message, isMine: isMine),
            ),
          );
        },
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final textColor = isMine ? AppColors.primaryForeground : AppColors.foreground;
    if (message.photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(message.photo!, width: 180, height: 180, fit: BoxFit.cover),
      );
    }
    if (message.location != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: textColor),
          const SizedBox(width: 4),
          Flexible(child: Text(message.location!, style: TextStyle(color: textColor))),
        ],
      );
    }
    return Text(message.content ?? '', style: TextStyle(color: textColor));
  }
}
