import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/books_repository.dart';
import '../data/bookshelf_repository.dart';

final _myShelfProvider = FutureProvider((ref) {
  return ref.watch(bookshelfRepositoryProvider).getMyShelf();
});

final _sharedBooksProvider = FutureProvider((ref) async {
  final books = await ref.watch(booksRepositoryProvider).getMyLibrary();
  return books.where((b) => b.availableForSwap).toList();
});

/// "Public Bookshelf" - raftul propriu, cu 3 stări gestionate explicit
/// (Reading/Want to Read/Finished, vezi BookshelfEntry în backend) plus
/// "Shared", derivat din cărțile deja listate la schimb (my-library).
class MyBookshelfScreen extends ConsumerWidget {
  const MyBookshelfScreen({super.key});

  Future<void> _pickAndImport(BuildContext context, WidgetRef ref, String source) async {
    final l10n = context.l10n;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file?.bytes == null) return;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final summary = await ref
          .read(bookshelfRepositoryProvider)
          .importCsv(source, bytes: file!.bytes!, filename: file.name);
      ref.invalidate(_myShelfProvider);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookshelfImportSummary(summary.imported, summary.skipped))),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
            : l10n.bookshelfImportError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.bookshelfTitle),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: l10n.bookshelfImportTooltip,
              onSelected: (source) => _pickAndImport(context, ref, source),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'goodreads', child: Text(l10n.bookshelfImportGoodreads)),
                PopupMenuItem(value: 'storygraph', child: Text(l10n.bookshelfImportStoryGraph)),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.bookshelfTabReading),
              Tab(text: l10n.bookshelfTabWantToRead),
              Tab(text: l10n.bookshelfTabFinished),
              Tab(text: l10n.bookshelfTabShared),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _ShelfList(section: _ShelfSection.reading),
              _ShelfList(section: _ShelfSection.wantToRead),
              _ShelfList(section: _ShelfSection.finished),
              _SharedList(),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ShelfSection { reading, wantToRead, finished }

class _ShelfList extends ConsumerWidget {
  const _ShelfList({required this.section});
  final _ShelfSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myShelfProvider);
    final l10n = context.l10n;

    return async.when(
      data: (shelf) {
        final books = switch (section) {
          _ShelfSection.reading => shelf.reading,
          _ShelfSection.wantToRead => shelf.wantToRead,
          _ShelfSection.finished => shelf.finished,
        };
        if (books.isEmpty) {
          return CenteredScrollable(child: Text(l10n.bookshelfEmpty));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final book = books[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: BookCover(url: book.coverUrl, width: 40, height: 56),
                title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: book.author != null ? Text(book.author!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.bookDetailShelfRemove,
                  onPressed: () async {
                    await ref.read(bookshelfRepositoryProvider).removeFromShelf(book.id);
                    ref.invalidate(_myShelfProvider);
                  },
                ),
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
            Text(l10n.bookshelfLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(_myShelfProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedList extends ConsumerWidget {
  const _SharedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_sharedBooksProvider);
    final l10n = context.l10n;

    return async.when(
      data: (books) {
        if (books.isEmpty) {
          return CenteredScrollable(child: Text(l10n.bookshelfEmpty));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 20,
              children: [
                for (final userBook in books)
                  BookCard(
                    userBook: userBook,
                    width: 140,
                    onTap: () => context.push('/books/${userBook.id}'),
                  ),
              ],
            ),
          ],
        );
      },
      loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
      error: (error, _) => CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.bookshelfLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(_sharedBooksProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
