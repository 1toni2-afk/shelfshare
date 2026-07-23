import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/book.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/books_repository.dart';

final _mostSharedProvider = FutureProvider((ref) {
  return ref.watch(booksRepositoryProvider).getMostSharedBooks();
});

final _trendingProvider = FutureProvider((ref) {
  return ref.watch(booksRepositoryProvider).getTrendingBooks();
});

final _popularAuthorsProvider = FutureProvider((ref) {
  return ref.watch(booksRepositoryProvider).getMostPopularAuthors();
});

/// Statistici globale de descoperire - agregate din activitatea tuturor
/// userilor, nu doar a celui curent (spre deosebire de LeaderboardScreen,
/// care rămâne despre useri/persoane).
class GlobalStatsScreen extends StatelessWidget {
  const GlobalStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.globalStatsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.globalStatsTabMostShared),
              Tab(text: l10n.globalStatsTabTrending),
              Tab(text: l10n.globalStatsTabPopularAuthors),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _BookStatList(provider: _mostSharedProvider, isTransferCount: true),
              _BookStatList(provider: _trendingProvider, isTransferCount: false),
              const _AuthorStatList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookStatList extends ConsumerWidget {
  const _BookStatList({required this.provider, required this.isTransferCount});
  final FutureProvider<List<BookStatEntry>> provider;
  final bool isTransferCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final l10n = context.l10n;

    return async.when(
      data: (entries) {
        if (entries.isEmpty) {
          return CenteredScrollable(child: Text(l10n.globalStatsEmpty));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(entry.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: entry.book.author != null ? Text(entry.book.author!) : null,
                trailing: Text(
                  isTransferCount
                      ? l10n.globalStatsTransferCount(entry.count)
                      : l10n.globalStatsViewCount(entry.count),
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
            Text(l10n.globalStatsLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(provider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorStatList extends ConsumerWidget {
  const _AuthorStatList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_popularAuthorsProvider);
    final l10n = context.l10n;

    return async.when(
      data: (entries) {
        if (entries.isEmpty) {
          return CenteredScrollable(child: Text(l10n.globalStatsEmpty));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(entry.author),
                trailing: Text(l10n.globalStatsTransferCount(entry.count)),
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
            Text(l10n.globalStatsLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(_popularAuthorsProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
