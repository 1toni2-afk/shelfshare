import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/application/book_detail_controller.dart';
import '../../books/data/bookshelf_repository.dart';
import '../data/collections_repository.dart';
import 'my_collections_screen.dart';

/// Deschide un bottom sheet cu toate listele în care poate intra o carte:
/// întâi cele trei rafturi fixe (citesc / vreau să citesc / citită), apoi
/// colecțiile proprii ale userului, ca checkbox-uri de apartenență.
///
/// Înainte, rafturile erau un rând separat de `ChoiceChip` direct pe ecranul de
/// detaliu, iar colecțiile un buton lângă el - două controale pentru aceeași
/// idee, care aglomerau ecranul. Acum e un singur „Adaugă în listă".
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

  /// Rafturile sunt exclusive între ele: un tap pe raftul curent îl scoate,
  /// un tap pe altul mută cartea acolo.
  Future<void> _toggleShelf(BookshelfStatus tapped, BookshelfStatus? current) async {
    final repository = ref.read(bookshelfRepositoryProvider);
    if (current == tapped) {
      await repository.removeFromShelf(widget.bookId);
    } else {
      await repository.setStatus(widget.bookId, tapped);
    }
    ref.invalidate(bookshelfStatusProvider(widget.bookId));
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
          ref.watch(bookshelfStatusProvider(widget.bookId)).when(
                data: (current) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in BookshelfStatus.values)
                      ChoiceChip(
                        label: Text(_shelfLabel(l10n, status)),
                        selected: current == status,
                        onSelected: (_) => _toggleShelf(status, current),
                      ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
          const SizedBox(height: 16),
          Text(
            l10n.collectionsTitle,
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 4),
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
                  textAlignVertical: TextAlignVertical.center,
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

  String _shelfLabel(AppLocalizations l10n, BookshelfStatus status) {
    switch (status) {
      case BookshelfStatus.reading:
        return l10n.bookshelfTabReading;
      case BookshelfStatus.wantToRead:
        return l10n.bookshelfTabWantToRead;
      case BookshelfStatus.finished:
        return l10n.bookshelfTabFinished;
    }
  }
}
