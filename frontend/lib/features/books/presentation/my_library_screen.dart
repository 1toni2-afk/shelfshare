import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/browser_download.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/my_library_controller.dart';

class MyLibraryScreen extends ConsumerStatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  ConsumerState<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends ConsumerState<MyLibraryScreen> {
  bool _sheetOpen = false;
  bool _isGridView = true;

  Future<void> _openActions(UserBook userBook) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _BookActionsSheet(userBook: userBook),
    );
    _sheetOpen = false;
  }

  void _exportCsv(List<UserBook> books) {
    final rows = [
      'Titlu,Autor,Stare,Limbă,Disponibilă la schimb,De vânzare,Preț',
      for (final b in books)
        [
          _csvEscape(b.book.title),
          _csvEscape(b.book.author ?? ''),
          b.condition.label,
          b.language ?? '',
          b.availableForSwap ? 'Da' : 'Nu',
          b.isForSale ? 'Da' : 'Nu',
          b.salePrice?.toStringAsFixed(0) ?? '',
        ].join(','),
    ];
    downloadTextFile(
      filename: 'biblioteca-shelfshare.csv',
      content: rows.join('\r\n'),
      mimeType: 'text/csv',
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myLibraryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca mea'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
            tooltip: _isGridView ? 'Vezi ca listă' : 'Vezi ca grilă',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exportă în CSV',
            onPressed: () => _exportCsv(state.value ?? const []),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/library/add'),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(myLibraryControllerProvider.notifier).refresh(),
          child: state.when(
            data: (books) {
              if (books.isEmpty) {
                return const CenteredScrollable(
                  child: Text('Nu ai nicio carte în bibliotecă încă.'),
                );
              }
              if (!_isGridView) {
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _MyLibraryListRow(
                    userBook: books[index],
                    onTap: () => _openActions(books[index]),
                  ),
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 20,
                    children: [
                      for (final userBook in books)
                        _MyLibraryCard(
                          userBook: userBook,
                          onTap: () => _openActions(userBook),
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
                  const Text('Nu am putut încărca biblioteca.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(myLibraryControllerProvider.notifier).refresh(),
                    child: const Text('Încearcă din nou'),
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

class _MyLibraryListRow extends StatelessWidget {
  const _MyLibraryListRow({required this.userBook, required this.onTap});
  final UserBook userBook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: BookCover(url: userBook.book.coverUrl, width: 44, height: 62),
        title: Text(userBook.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (userBook.book.author != null) userBook.book.author!,
            userBook.condition.label,
            if (userBook.isForSale && userBook.salePrice != null)
              '${userBook.salePrice!.toStringAsFixed(0)} lei',
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: userBook.availableForSwap
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            userBook.availableForSwap ? 'Disponibilă' : 'Indisponibilă',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: userBook.availableForSwap ? AppColors.accent : AppColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _MyLibraryCard extends StatelessWidget {
  const _MyLibraryCard({required this.userBook, required this.onTap});
  final UserBook userBook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCard(userBook: userBook, onTap: onTap, width: 160),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: userBook.availableForSwap
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : AppColors.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              userBook.availableForSwap ? 'Disponibilă' : 'Indisponibilă',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: userBook.availableForSwap ? AppColors.accent : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookActionsSheet extends ConsumerWidget {
  const _BookActionsSheet({required this.userBook});
  final UserBook userBook;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergi cartea?'),
        content: Text('"${userBook.book.title}" va fi eliminată din bibliotecă.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(myLibraryControllerProvider.notifier).deleteBook(userBook.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(myLibraryControllerProvider).value ?? const [];
    final current = books.firstWhere(
      (book) => book.id == userBook.id,
      orElse: () => userBook,
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(current.book.title, style: Theme.of(context).textTheme.titleLarge),
          ),
          SwitchListTile(
            title: const Text('Disponibilă pentru schimb'),
            value: current.availableForSwap,
            onChanged: (value) => ref
                .read(myLibraryControllerProvider.notifier)
                .setAvailability(userBook.id, availableForSwap: value),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.destructive),
            title: const Text('Șterge cartea', style: TextStyle(color: AppColors.destructive)),
            onTap: () => _confirmDelete(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
