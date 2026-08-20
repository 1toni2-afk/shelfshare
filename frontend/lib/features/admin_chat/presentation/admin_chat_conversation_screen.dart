import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_chat_repository.dart';
import 'admin_chat_inbox_screen.dart';

final _adminChatMessagesProvider =
    FutureProvider.autoDispose.family<AdminChatConversation, String>((ref, conversationId) async {
  final repo = ref.watch(adminChatRepositoryProvider);
  final conversation = await repo.getConversationMessages(conversationId);
  await repo.markConversationReadByAdmin(conversationId);
  return conversation;
});

/// Un admin oarecare poate deschide și răspunde la orice conversație - nu
/// există un "admin asignat" (vezi backend/src/admin-chat/admin-chat.service.ts).
class AdminChatConversationScreen extends ConsumerStatefulWidget {
  const AdminChatConversationScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<AdminChatConversationScreen> createState() => _AdminChatConversationScreenState();
}

class _AdminChatConversationScreenState extends ConsumerState<AdminChatConversationScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(adminChatRepositoryProvider).sendAdminReply(widget.conversationId, text);
      _controller.clear();
      ref.invalidate(_adminChatMessagesProvider(widget.conversationId));
      ref.invalidate(adminChatConversationsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.commonGenericError)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(_adminChatMessagesProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        title: async.maybeWhen(
          data: (conversation) => Text(
            conversation.userName?.isNotEmpty == true
                ? conversation.userName!
                : (conversation.userEmail ?? l10n.adminChatTitle),
          ),
          orElse: () => Text(l10n.adminChatTitle),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: async.when(
                data: (conversation) {
                  if (conversation.messages.isEmpty) {
                    return Center(child: Text(l10n.adminChatEmpty));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: conversation.messages.length,
                    itemBuilder: (context, index) {
                      final message = conversation.messages[index];
                      return _MessageBubble(content: message.content, isMine: message.isFromAdmin);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(l10n.commonGenericError)),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: l10n.adminChatInputHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.content, required this.isMine});
  final String content;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(content, style: TextStyle(color: isMine ? AppColors.primaryForeground : null)),
      ),
    );
  }
}
