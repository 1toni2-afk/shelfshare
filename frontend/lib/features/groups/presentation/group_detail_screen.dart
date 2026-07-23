import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/group.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/groups_repository.dart';
import 'groups_screen.dart';

final _groupProvider = FutureProvider.family<BookGroup, String>((ref, id) {
  return ref.watch(groupsRepositoryProvider).getOne(id);
});

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _postController = TextEditingController();

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    await ref.read(groupsRepositoryProvider).join(widget.groupId);
    ref.invalidate(_groupProvider(widget.groupId));
    ref.invalidate(myGroupsProvider);
  }

  Future<void> _leave() async {
    await ref.read(groupsRepositoryProvider).leave(widget.groupId);
    ref.invalidate(_groupProvider(widget.groupId));
    ref.invalidate(myGroupsProvider);
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.groupsDeleteConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonGiveUp)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(groupsRepositoryProvider).delete(widget.groupId);
    ref.invalidate(myGroupsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _submitPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;
    await ref.read(groupsRepositoryProvider).createPost(widget.groupId, content);
    _postController.clear();
    ref.invalidate(_groupProvider(widget.groupId));
  }

  Future<void> _addEvent() async {
    final l10n = context.l10n;
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? date;
    TimeOfDay? time;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.groupsAddEventTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.groupsEventTitleLabel),
              ),
              TextField(
                controller: locationController,
                decoration: InputDecoration(labelText: l10n.groupsEventLocationLabel),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 1),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                      child: Text(date == null ? l10n.chatPickDate : '${date!.day}.${date!.month}.${date!.year}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) setState(() => time = picked);
                      },
                      child: Text(time == null ? l10n.chatPickTime : time!.format(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonGiveUp)),
            TextButton(
              onPressed: (titleController.text.trim().isEmpty || date == null || time == null)
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: Text(l10n.commonSubmit),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || date == null || time == null) return;

    final eventAt = DateTime(date!.year, date!.month, date!.day, time!.hour, time!.minute);
    await ref.read(groupsRepositoryProvider).createEvent(
          widget.groupId,
          title: titleController.text.trim(),
          location: locationController.text.trim(),
          eventAt: eventAt,
        );
    ref.invalidate(_groupProvider(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_groupProvider(widget.groupId));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.value?.name ?? l10n.groupsTitle),
        actions: [
          if (async.value?.isAdmin == true)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: async.when(
          data: (group) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (group.description != null) ...[
                Text(group.description!),
                const SizedBox(height: 8),
              ],
              Text(
                l10n.groupsMemberCount(group.memberCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 12),
              if (!group.isMember)
                ElevatedButton(onPressed: _join, child: Text(l10n.groupsJoin))
              else if (!group.isAdmin)
                OutlinedButton(onPressed: _leave, child: Text(l10n.groupsLeave)),
              const SizedBox(height: 24),
              Text(l10n.groupsEventsTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (group.events.isEmpty)
                Text(l10n.groupsNoEvents)
              else
                for (final event in group.events)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text(event.title),
                      subtitle: Text(
                        [
                          '${event.eventAt.day}.${event.eventAt.month}.${event.eventAt.year} '
                              '${event.eventAt.hour.toString().padLeft(2, '0')}:${event.eventAt.minute.toString().padLeft(2, '0')}',
                          if (event.location != null) event.location!,
                        ].join(' · '),
                      ),
                    ),
                  ),
              if (group.isMember)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addEvent,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.groupsAddEventTitle),
                  ),
                ),
              const SizedBox(height: 24),
              Text(l10n.groupsDiscussionTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (group.isMember)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        decoration: InputDecoration(hintText: l10n.groupsPostHint),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.send), onPressed: _submitPost),
                  ],
                ),
              const SizedBox(height: 12),
              if (group.posts.isEmpty)
                Text(l10n.groupsNoPosts)
              else
                for (final post in group.posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorUsername ?? post.authorName ?? l10n.commonUnknownUser,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(post.content),
                      ],
                    ),
                  ),
            ],
          ),
          loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
          error: (error, _) => CenteredScrollable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.groupsLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_groupProvider(widget.groupId)),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
