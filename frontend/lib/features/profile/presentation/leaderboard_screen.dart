import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/profile_repository.dart';

final _cityLeaderboardProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getCityLeaderboard();
});

final _nationalLeaderboardProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getNationalLeaderboard();
});

final _topReadersProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getTopReaders();
});

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileLeaderboard),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.leaderboardTabCity),
              Tab(text: l10n.leaderboardTabNational),
              Tab(text: l10n.leaderboardTabTopReaders),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _LeaderboardList(provider: _cityLeaderboardProvider, showCity: true),
              _LeaderboardList(provider: _nationalLeaderboardProvider, showCity: false),
              const _TopReadersList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopReadersList extends ConsumerWidget {
  const _TopReadersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_topReadersProvider);
    final l10n = context.l10n;

    return async.when(
      data: (entries) {
        if (entries.isEmpty) {
          return CenteredScrollable(child: Text(l10n.leaderboardEmpty));
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
                onTap: () => context.push('/users/${entry.id}'),
                leading: CircleAvatar(
                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(entry.name ?? l10n.commonUnknownUser),
                subtitle: Text(entry.city ?? ''),
                trailing: Text(l10n.leaderboardPagesCount(entry.totalPages)),
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
            Text(l10n.leaderboardLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(_topReadersProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardList extends ConsumerWidget {
  const _LeaderboardList({required this.provider, required this.showCity});
  final FutureProvider<List<CityLeaderboardEntry>> provider;
  final bool showCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final l10n = context.l10n;

    return async.when(
      data: (entries) {
        if (entries.isEmpty) {
          return CenteredScrollable(child: Text(l10n.leaderboardEmpty));
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
                onTap: showCity ? null : () => context.push('/users/${entry.id}'),
                leading: CircleAvatar(
                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(
                  showCity ? (entry.city ?? l10n.leaderboardUnknownCity) : (entry.name ?? l10n.commonUnknownUser),
                ),
                subtitle: showCity
                    ? GestureDetector(
                        onTap: () => context.push('/users/${entry.id}'),
                        child: Text(
                          entry.name ?? l10n.commonUnknownUser,
                          style: const TextStyle(decoration: TextDecoration.underline),
                        ),
                      )
                    : Text(entry.city ?? l10n.leaderboardUnknownCity),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l10n.leaderboardExchangesCount(entry.booksExchangedCount)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.accent),
                        Text(' ${entry.rating.toStringAsFixed(1)}'),
                      ],
                    ),
                  ],
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
            Text(l10n.leaderboardLoadError),
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
