import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/my_library_controller.dart';

class MyLibraryScreen extends ConsumerStatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  ConsumerState<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends ConsumerState<MyLibraryScreen> {
  bool _sheetOpen = false;

  Future<void> _openActions(UserBook userBook) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _BookActionsSheet(userBook: userBook),
    );
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myLibraryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca mea')),
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
