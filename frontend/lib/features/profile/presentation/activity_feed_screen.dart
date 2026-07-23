import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../l10n/app_localizations.dart';
import '../data/profile_repository.dart';

final _activityFeedProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getActivityFeed();
});

/// Reading Activity Feed - evenimente recente din activitatea userilor
/// urmăriți (Follow), recompuse din date deja existente (nicio tabelă de
/// evenimente dedicată - vezi getActivityFeed în backend).
class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_activityFeedProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityFeedTitle)),
      body: SafeArea(
        child: async.when(
          data: (events) {
            if (events.isEmpty) {
              return CenteredScrollable(child: Text(l10n.activityFeedEmpty));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => context.push('/users/${event.userId}'),
                    leading: BookCover(url: event.bookCoverUrl, width: 40, height: 56),
                    title: Text(_labelFor(l10n, event)),
                    subtitle: Text(event.bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Icon(_iconFor(event.type), color: AppColors.mutedForeground, size: 18),
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
                Text(l10n.activityFeedLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_activityFeedProvider),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, ActivityEvent event) {
    final name = event.userName ?? l10n.commonUnknownUser;
    switch (event.type) {
      case 'new_listing':
        return l10n.activityNewListing(name);
      case 'finished_book':
        return l10n.activityFinishedBook(name);
      case 'completed_exchange':
        return l10n.activityCompletedExchange(name);
      default:
        return name;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_listing':
        return Icons.auto_stories_outlined;
      case 'finished_book':
        return Icons.check_circle_outline;
      case 'completed_exchange':
        return Icons.swap_horiz;
      default:
        return Icons.circle_outlined;
    }
  }
}
