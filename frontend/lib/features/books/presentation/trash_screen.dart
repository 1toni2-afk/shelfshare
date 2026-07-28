import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/my_library_controller.dart';
import '../data/books_repository.dart';

/// „Coșul de gunoi" - cărți șterse recent care mai pot fi restaurate. După 7
/// zile de la ștergere, cron-ul de pe backend le dispariție definitiv.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(deletedBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTrash)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(deletedBooksProvider),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => CenteredScrollable(child: Text(l10n.homeLoadError)),
            data: (items) {
              if (items.isEmpty) {
                return CenteredScrollable(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, size: 48, color: AppColors.mutedForeground),
                      const SizedBox(height: 12),
                      Text(l10n.libraryTrashEmpty),
                    ],
                  ),
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.libraryTrashHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  return _TrashRow(userBook: items[index - 1]);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrashRow extends ConsumerWidget {
  const _TrashRow({required this.userBook});
  final UserBook userBook;

  int get _daysLeft {
    if (userBook.deletedAt == null) return 7;
    final expires = userBook.deletedAt!.add(const Duration(days: 7));
    final left = expires.difference(DateTime.now()).inDays;
    return left.clamp(0, 7);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(booksRepositoryProvider).restoreBook(userBook.id);
      ref.invalidate(deletedBooksProvider);
      ref.read(myLibraryControllerProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.libraryRestored)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.homeLoadError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: BookCover(url: userBook.book.coverUrl, width: 40, height: 56),
        title: Text(userBook.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          l10n.inventoryDeletedDaysLeft(_daysLeft),
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.restore),
          label: Text(l10n.libraryRestore),
          onPressed: () => _restore(context, ref),
        ),
      ),
    );
  }
}
