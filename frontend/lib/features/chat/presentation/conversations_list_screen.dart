import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/conversations_controller.dart';

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navChat)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(conversationsControllerProvider.notifier).refresh(),
          child: state.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return CenteredScrollable(child: Text(l10n.chatEmptyConversations));
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final lastMessage = conversation.lastMessage;
                  final preview = lastMessage == null
                      ? l10n.chatStartConversation
                      : lastMessage.content ??
                          (lastMessage.photo != null ? l10n.chatPhotoPreview : l10n.chatLocationPreview);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: conversation.otherUser.profileImage != null
                          ? NetworkImage(conversation.otherUser.profileImage!)
                          : null,
                      child: conversation.otherUser.profileImage == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(conversation.otherUser.name ?? l10n.commonUnknownUser),
                    subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => context.push(
                      '/chat/${conversation.id}',
                      extra: conversation.otherUser,
                    ),
                  );
                },
              );
            },
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.chatLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(conversationsControllerProvider.notifier).refresh(),
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
