import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_chat_repository.dart';

final _myAdminConversationProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(adminChatRepositoryProvider);
  final conversation = await repo.getMyConversation();
  // Deschiderea ecranului marchează conversația citită - altfel un răspuns
  // de admin ar rămâne "necitit" la nesfârșit din perspectiva userului.
  await repo.markMyConversationRead();
  return conversation;
});

/// „Chat with an admin" - ecranul userului obișnuit. Nu e legat de un admin
/// anume: mesajul ajunge la echipa de admini, oricare poate răspunde (vezi
/// backend/src/admin-chat).
class AdminChatScreen extends ConsumerStatefulWidget {
  const AdminChatScreen({super.key});

  @override
  ConsumerState<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends ConsumerState<AdminChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  // Fără focusNode dedicat, apăsarea Enter (onSubmitted) declanșează și
  // comportamentul implicit al TextField de a-și pierde focusul după submit
  // - userul trebuia să dea din nou click în câmp după fiecare mesaj. Vezi
  // conversation_screen.dart pentru același fix.
  final _messageFocusNode = FocusNode();
  final _sendButtonFocusNode = FocusNode(canRequestFocus: false, skipTraversal: true);
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _sendButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(adminChatRepositoryProvider).sendMyMessage(text);
      _controller.clear();
      ref.invalidate(_myAdminConversationProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.commonGenericError)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      // Comportamentul implicit de submit al TextField (textAlignVertical: TextAlignVertical.center, Enter) scoate focusul
      // DUPĂ ce onSubmitted rulează - un requestFocus() sincron aici ar fi
      // depășit de el. Cerem focus într-un post-frame callback, ca să câștige
      // mereu, indiferent dacă trimiterea a fost prin Enter sau prin buton.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _messageFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(_myAdminConversationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminChatTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: async.when(
                data: (conversation) {
                  if (conversation.messages.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: const _ModeratorGuidelines(),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: conversation.messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: _ModeratorGuidelines(),
                        );
                      }
                      final message = conversation.messages[index - 1];
                      return _MessageBubble(
                        content: message.content,
                        isMine: !message.isFromAdmin,
                        createdAt: message.createdAt,
                      );
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
                        focusNode: _messageFocusNode,
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
                      focusNode: _sendButtonFocusNode,
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

/// Mesajul „by default" + reguli, cerut explicit: userul trebuie să vadă
/// clar ce e acest chat înainte să scrie, nu doar un placeholder gol. Rămâne
/// vizibil și după primul mesaj (ancorat sus în listă), nu doar la gol -
/// ghidul e util pe tot parcursul conversației, nu doar la prima vizită.
class _ModeratorGuidelines extends StatelessWidget {
  const _ModeratorGuidelines();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.adminChatGuidelinesTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.adminChatGuidelinesIntro, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            _GuidelineItem(text: l10n.adminChatGuidelineResponseTime),
            _GuidelineItem(text: l10n.adminChatGuidelineNoSpam),
            _GuidelineItem(text: l10n.adminChatGuidelineBeRespectful),
          ],
        ),
      ),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  const _GuidelineItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.circle, size: 5, color: AppColors.mutedForeground),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.content, required this.isMine, required this.createdAt});
  final String content;
  final bool isMine;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final local = createdAt.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: TextStyle(color: isMine ? AppColors.primaryForeground : null),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isMine
                        ? AppColors.primaryForeground.withValues(alpha: 0.7)
                        : AppColors.mutedForeground,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
