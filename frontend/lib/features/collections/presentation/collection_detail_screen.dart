import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/collection.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/collections_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import 'my_collections_screen.dart';

final _collectionProvider = FutureProvider.family<BookCollection, String>((ref, id) {
  return ref.watch(collectionsRepositoryProvider).getOne(id);
});

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId, this.ownerId});
  final String collectionId;
  final String? ownerId;

  bool _isOwner(WidgetRef ref) {
    if (ownerId == null) return true;
    final authState = ref.read(authControllerProvider);
    return authState is AuthAuthenticated && authState.user.id == ownerId;
  }

  Future<void> _removeBook(BuildContext context, WidgetRef ref, String bookId) async {
    await ref.read(collectionsRepositoryProvider).removeBook(collectionId, bookId);
    ref.invalidate(_collectionProvider(collectionId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.collectionsDeleteConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonGiveUp)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(collectionsRepositoryProvider).delete(collectionId);
    ref.invalidate(myCollectionsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _togglePublic(WidgetRef ref, BookCollection collection) async {
    await ref.read(collectionsRepositoryProvider).update(collectionId, isPublic: !collection.isPublic);
    ref.invalidate(_collectionProvider(collectionId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_collectionProvider(collectionId));
    final l10n = context.l10n;
    final isOwner = _isOwner(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(async.value?.name ?? l10n.collectionsTitle),
        actions: isOwner
            ? [
                if (async.value != null)
                  IconButton(
                    icon: Icon(async.value!.isPublic ? Icons.public : Icons.lock_outline),
                    tooltip: l10n.collectionsPublicSwitch,
                    onPressed: () => _togglePublic(ref, async.value!),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: async.when(
          data: (collection) {
            if (collection.items.isEmpty) {
              return CenteredScrollable(child: Text(l10n.collectionsEmptyItems));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: collection.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final book = collection.items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: BookCover(url: book.coverUrl, width: 44, height: 62),
                  title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: book.author != null ? Text(book.author!) : null,
                  trailing: isOwner
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeBook(context, ref, book.id),
                        )
                      : null,
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
                  onPressed: () => ref.invalidate(_collectionProvider(collectionId)),
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
