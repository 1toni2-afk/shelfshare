import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../data/collections_repository.dart';
import 'my_collections_screen.dart';

/// Deschide un bottom sheet cu colecțiile proprii ale userului, ca checkbox-
/// uri de apartenență pentru o carte anume - vezi butonul "Adaugă în colecție"
/// de pe ecranul de detaliu al cărții.
Future<void> showAddToCollectionSheet(BuildContext context, {required String bookId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddToCollectionSheet(bookId: bookId),
  );
}

class _AddToCollectionSheet extends ConsumerStatefulWidget {
  const _AddToCollectionSheet({required this.bookId});
  final String bookId;

  @override
  ConsumerState<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<_AddToCollectionSheet> {
  final _nameController = TextEditingController();
  final Set<String> _busyIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _toggle(String collectionId, bool alreadyIn) async {
    setState(() => _busyIds.add(collectionId));
    try {
      if (alreadyIn) {
        await ref.read(collectionsRepositoryProvider).removeBook(collectionId, widget.bookId);
      } else {
        await ref.read(collectionsRepositoryProvider).addBook(collectionId, widget.bookId);
      }
      ref.invalidate(myCollectionsProvider);
    } finally {
      if (mounted) setState(() => _busyIds.remove(collectionId));
    }
  }

  Future<void> _createAndAdd() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final collection = await ref.read(collectionsRepositoryProvider).create(name);
    await ref.read(collectionsRepositoryProvider).addBook(collection.id, widget.bookId);
    _nameController.clear();
    ref.invalidate(myCollectionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(myCollectionsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.collectionsAddToTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          async.when(
            data: (collections) => ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: collections.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(l10n.collectionsEmpty),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        final alreadyIn = collection.items.any((b) => b.id == widget.bookId);
                        final busy = _busyIds.contains(collection.id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(collection.name),
                          value: alreadyIn,
                          onChanged: busy ? null : (_) => _toggle(collection.id, alreadyIn),
                        );
                      },
                    ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(l10n.collectionsLoadError),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(hintText: l10n.collectionsNewInline),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _createAndAdd, child: Text(l10n.commonSubmit)),
            ],
          ),
        ],
      ),
    );
  }
}
