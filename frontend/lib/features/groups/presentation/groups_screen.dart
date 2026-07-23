import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/group.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/groups_repository.dart';

final publicGroupsProvider = FutureProvider((ref) {
  return ref.watch(groupsRepositoryProvider).getPublicGroups();
});

final myGroupsProvider = FutureProvider((ref) {
  return ref.watch(groupsRepositoryProvider).getMine();
});

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    var isPublic = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.groupsCreateTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.groupsNameLabel),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: l10n.groupsDescriptionLabel),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.collectionsPublicSwitch),
                value: isPublic,
                onChanged: (value) => setState(() => isPublic = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonGiveUp)),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonSubmit)),
          ],
        ),
      ),
    );
    if (result != true || nameController.text.trim().isEmpty) return;

    final group = await ref.read(groupsRepositoryProvider).create(
          nameController.text.trim(),
          description: descriptionController.text.trim(),
          isPublic: isPublic,
        );
    ref.invalidate(publicGroupsProvider);
    ref.invalidate(myGroupsProvider);
    if (context.mounted) context.push('/groups/${group.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.groupsTitle),
          bottom: TabBar(tabs: [Tab(text: l10n.groupsTabDiscover), Tab(text: l10n.groupsTabMine)]),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _create(context, ref),
          child: const Icon(Icons.add),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _GroupList(provider: publicGroupsProvider),
              _GroupList(provider: myGroupsProvider),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupList extends ConsumerWidget {
  const _GroupList({required this.provider});
  final FutureProvider<List<BookGroup>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final l10n = context.l10n;

    return async.when(
      data: (groups) {
        if (groups.isEmpty) {
          return CenteredScrollable(child: Text(l10n.groupsEmpty));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(group.name),
                subtitle: Text(l10n.groupsMemberCount(group.memberCount)),
                trailing: group.isPublic ? null : const Icon(Icons.lock_outline),
                onTap: () => context.push('/groups/${group.id}'),
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
            Text(l10n.groupsLoadError),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => ref.invalidate(provider), child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
