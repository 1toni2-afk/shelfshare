import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/books_repository.dart';

final _smartMatchesProvider = FutureProvider((ref) {
  return ref.watch(booksRepositoryProvider).getSmartMatches();
});

/// "Smart Swap / Auto Match" - useri cu care există o dublă coincidență de
/// dorințe (ei au ce vrei tu, tu ai ce vor ei) - vezi getSmartMatches în
/// backend pentru algoritm.
class SmartMatchesScreen extends ConsumerWidget {
  const SmartMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_smartMatchesProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.smartMatchesTitle)),
      body: SafeArea(
        child: async.when(
          data: (matches) {
            if (matches.isEmpty) {
              return CenteredScrollable(child: Text(l10n.smartMatchesEmpty));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _SmartMatchCard(match: matches[index]),
            );
          },
          loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
          error: (error, _) => CenteredScrollable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.smartMatchesLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_smartMatchesProvider),
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

class _SmartMatchCard extends StatelessWidget {
  const _SmartMatchCard({required this.match});
  final SmartMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push('/users/${match.owner.id}', extra: match.owner),
              leading: CircleAvatar(
                backgroundImage:
                    match.owner.profileImage != null ? NetworkImage(match.owner.profileImage!) : null,
                child: match.owner.profileImage == null ? const Icon(Icons.person_outline) : null,
              ),
              title: Text(match.owner.name ?? l10n.commonUnknownUser),
              subtitle: Text(match.owner.city ?? ''),
            ),
            const SizedBox(height: 8),
            Text(l10n.smartMatchesTheyHave, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                )),
            const SizedBox(height: 8),
            _BookRow(books: match.theirBooks),
            const SizedBox(height: 16),
            Text(l10n.smartMatchesTheyWant, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                )),
            const SizedBox(height: 8),
            _BookRow(books: match.myBooksTheyWant),
          ],
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.books});
  final List<SmartMatchBook> books;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final book = books[index];
          return GestureDetector(
            onTap: () => context.push('/books/${book.userBookId}'),
            child: SizedBox(
              width: 60,
              child: Column(
                children: [
                  BookCover(url: book.coverUrl, width: 60, height: 70),
                  const SizedBox(height: 4),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
