import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/admin_chat_repository.dart';

final adminChatConversationsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(adminChatRepositoryProvider).getAllConversations();
});

/// Inbox-ul de admin pentru „chat with an admin" - vizibil oricărui admin
/// (nu doar celui care a răspuns primul, vezi backend/src/admin-chat). Toate
/// conversațiile sunt aici, indiferent care admin a scris ultimul.
class AdminChatInboxScreen extends ConsumerWidget {
  const AdminChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(adminChatConversationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminChatInboxTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(adminChatConversationsProvider.future),
          child: async.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return CenteredScrollable(child: Text(l10n.adminChatInboxEmpty));
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: conv.hasUnread ? AppColors.primary : AppColors.mutedForeground,
                        child: const Icon(Icons.person_outline, color: Colors.white),
                      ),
                      title: Text(conv.userName?.isNotEmpty == true ? conv.userName! : conv.userEmail),
                      subtitle: conv.lastMessageContent != null
                          ? Text(
                              conv.lastMessageContent!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: conv.hasUnread
                                  ? const TextStyle(fontWeight: FontWeight.bold)
                                  : null,
                            )
                          : null,
                      trailing: conv.hasUnread
                          ? const Icon(Icons.circle, size: 10, color: AppColors.primary)
                          : const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin/chat/${conv.id}'),
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
                  Text(l10n.commonGenericError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(adminChatConversationsProvider),
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
