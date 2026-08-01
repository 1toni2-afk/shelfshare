import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/conversation.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/conversations_controller.dart';

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key, this.archived = false});

  /// Același ecran servește și arhiva - vezi ruta /chat/archived.
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsControllerProvider(archived));
    final l10n = context.l10n;

    // Numărul de chaturi arhivate se citește din cealaltă listă, ca intrarea
    // „Arhivate" din inbox să fie corectă fără încă un endpoint.
    final archivedCount = archived
        ? 0
        : ref.watch(conversationsControllerProvider(true)).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(archived ? l10n.chatArchivedTitle : l10n.navChat)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(conversationsControllerProvider(archived).notifier).refresh(),
          child: state.when(
            data: (conversations) {
              if (conversations.isEmpty && archivedCount == 0) {
                return CenteredScrollable(
                  child: Text(archived ? l10n.chatEmptyArchived : l10n.chatEmptyConversations),
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: conversations.length + (archivedCount > 0 ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (archivedCount > 0 && index == 0) {
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.archive_outlined)),
                      title: Text(l10n.chatArchivedTitle),
                      trailing: Text('$archivedCount'),
                      onTap: () => context.push('/chat/archived'),
                    );
                  }
                  final conversation =
                      conversations[archivedCount > 0 ? index - 1 : index];
                  return _ConversationTile(conversation: conversation, archived: archived);
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
                    onPressed: () => ref
                        .read(conversationsControllerProvider(archived).notifier)
                        .refresh(),
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

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.archived});
  final Conversation conversation;
  final bool archived;

  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lastMessage = conversation.lastMessage;
    final preview = lastMessage == null
        ? l10n.chatStartConversation
        : lastMessage.content ??
            (lastMessage.photo != null ? l10n.chatPhotoPreview : l10n.chatLocationPreview);
    final hasUnread = conversation.unreadCount > 0;
    final notifier = ref.read(conversationsControllerProvider(archived).notifier);

    return Dismissible(
      key: ValueKey(conversation.id),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: AppColors.accent,
        icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
        label: archived ? l10n.chatUnarchive : l10n.chatArchive,
      ),
      secondaryBackground: const _SwipeBackground(
        alignment: Alignment.centerRight,
        color: AppColors.destructive,
        icon: Icons.delete_outline,
        label: null,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await notifier.setArchived(conversation.id, !archived);
          // Rândul dispare oricum când lista se reîncarcă din provider, deci
          // nu îl scoatem și manual din arbore (ar da un rebuild dublu).
          return false;
        }
        if (!await _confirmDelete(context)) return false;
        await notifier.delete(conversation.id);
        return false;
      },
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundImage: conversation.otherUser.profileImage != null
                  ? NetworkImage(conversation.otherUser.profileImage!)
                  : null,
              child: conversation.otherUser.profileImage == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            if (conversation.otherUser.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          conversation.otherUser.name ?? l10n.commonUnknownUser,
          style: hasUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: hasUnread
              ? TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                )
              : null,
        ),
        trailing: hasUnread
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                alignment: Alignment.center,
                child: Text(
                  conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: AppColors.primaryForeground,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () => context.push('/chat/${conversation.id}', extra: conversation.otherUser),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.15),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label!, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
