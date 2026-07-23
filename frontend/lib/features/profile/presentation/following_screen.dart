import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/follow_repository.dart';

final _followingProvider = FutureProvider((ref) {
  return ref.watch(followRepositoryProvider).getFollowing();
});

/// "Vânzători/schimbători favoriți" - lista userilor pe care îi urmărește
/// userul curent, ca punct central de unde să-i regăsească rapid, în loc să
/// depindă doar de badge-ul de follow văzut pe fiecare profil vizitat.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_followingProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoriteSellersTitle)),
      body: SafeArea(
        child: async.when(
          data: (users) {
            if (users.isEmpty) {
              return CenteredScrollable(child: Text(l10n.favoriteSellersEmpty));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => context.push('/users/${user.id}'),
                    leading: CircleAvatar(
                      backgroundImage: user.profileImage != null ? NetworkImage(user.profileImage!) : null,
                      child: user.profileImage == null ? const Icon(Icons.person_outline) : null,
                    ),
                    title: Text(user.name ?? l10n.commonUnknownUser),
                    subtitle: Text(user.city ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.accent),
                        Text(' ${user.rating.toStringAsFixed(1)}'),
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
                Text(l10n.favoriteSellersLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_followingProvider),
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
