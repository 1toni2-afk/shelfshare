import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/profile_repository.dart';

final _leaderboardProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getCityLeaderboard();
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clasament pe orașe')),
      body: SafeArea(
        child: async.when(
          data: (entries) {
            if (entries.isEmpty) {
              return const CenteredScrollable(
                child: Text('Niciun oraș cu activitate încă.'),
              );
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
                    title: Text(entry.city ?? 'Necunoscut'),
                    subtitle: GestureDetector(
                      onTap: () => context.push('/users/${entry.id}'),
                      child: Text(
                        entry.name ?? 'Utilizator',
                        style: const TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${entry.booksExchangedCount} schimburi'),
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
                const Text('Nu am putut încărca clasamentul.'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_leaderboardProvider),
                  child: const Text('Încearcă din nou'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
