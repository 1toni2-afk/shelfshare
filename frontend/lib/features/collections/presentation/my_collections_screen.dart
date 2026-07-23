import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/collections_repository.dart';

final myCollectionsProvider = FutureProvider((ref) {
  return ref.watch(collectionsRepositoryProvider).getMine();
});

class MyCollectionsScreen extends ConsumerWidget {
  const MyCollectionsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final nameController = TextEditingController();
    var isPublic = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.collectionsCreateTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.collectionsNameLabel),
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

    await ref.read(collectionsRepositoryProvider).create(nameController.text.trim(), isPublic: isPublic);
    ref.invalidate(myCollectionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCollectionsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.collectionsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: async.when(
          data: (collections) {
            if (collections.isEmpty) {
              return CenteredScrollable(child: Text(l10n.collectionsEmpty));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: collections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final collection = collections[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(collection.name),
                    subtitle: Text(l10n.collectionsBookCount(collection.itemCount)),
                    trailing: Icon(
                      collection.isPublic ? Icons.public : Icons.lock_outline,
                      color: AppColors.mutedForeground,
                    ),
                    onTap: () => context.push('/collections/${collection.id}'),
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
                Text(l10n.collectionsLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(myCollectionsProvider),
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
