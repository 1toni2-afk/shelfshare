import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/genre_localization.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../books/presentation/browse_screen.dart' show SearchScreenArgs;
import '../application/activity_feed_controller.dart';

/// Reading Activity Feed - evenimente recente din activitatea userilor
/// urmăriți (Follow), recompuse din date deja existente (nicio tabelă de
/// evenimente dedicată - vezi getActivityFeed în backend). Paginat prin
/// scroll infinit (ActivityFeedController), la fel ca Browse.
///
/// Layout tip "social feed" (card pe eveniment, copertă mare, insignă de tip),
/// cerut explicit ca redesign - fără rândul de „poveste" din partea de sus
/// (genul Instagram Stories), care nu are corespondent funcțional aici.
/// Rândul de acțiuni (like/comentariu/salvare) din concept a fost omis
/// intenționat: fără un model de date real în spate (evenimentele sunt
/// derivate, nu rânduri persistente cu id stabil), afișarea unor contoare
/// fixe ar fi fost UI decorativ, nu funcțional - tot cardul e tappable spre
/// căutarea titlului în schimb.
class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(activityFeedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityFeedControllerProvider);
    final l10n = context.l10n;

    Widget body;
    if (state.isLoading) {
      body = const CenteredScrollable(child: CircularProgressIndicator());
    } else if (state.hasError) {
      body = CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.activityFeedLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.read(activityFeedControllerProvider.notifier).refresh(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    } else if (state.events.isEmpty) {
      body = CenteredScrollable(child: Text(l10n.activityFeedEmpty));
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.read(activityFeedControllerProvider.notifier).refresh(),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.events.length + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.events.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ActivityCard(event: state.events[index]),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityFeedTitle)),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: body))),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.event});
  final ActivityEvent event;

  (String, Color) _badge(BuildContext context) {
    final l10n = context.l10n;
    switch (event.type) {
      case 'new_listing':
        return (l10n.activityBadgeNew, AppColors.accent);
      case 'finished_book':
        return (l10n.activityBadgeFinished, AppColors.primary);
      case 'completed_exchange':
        return (l10n.activityBadgeExchange, AppColors.success);
      case 'sale':
        return (l10n.activityBadgeSale, AppColors.warning);
      case 'reading_progress':
        return (l10n.activityBadgeProgress, AppColors.primary);
      default:
        return ('', AppColors.mutedForeground);
    }
  }

  String _verb(AppLocalizations l10n) {
    switch (event.type) {
      case 'new_listing':
        return l10n.activityNewListing;
      case 'finished_book':
        return l10n.activityFinishedBook;
      case 'completed_exchange':
        return l10n.activityCompletedExchange;
      case 'sale':
        return l10n.activitySale(_formatAmount(event.amount ?? 0));
      case 'reading_progress':
        return l10n.activityReadingProgress;
      default:
        return '';
    }
  }

  String _formatAmount(double amount) {
    return amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  String _relativeTime(AppLocalizations l10n, DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = event.userName ?? l10n.commonUnknownUser;
    final (badgeLabel, badgeColor) = _badge(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/browse', extra: SearchScreenArgs(title: event.bookTitle)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.muted,
                    backgroundImage: event.userAvatar != null ? NetworkImage(event.userAvatar!) : null,
                    child: event.userAvatar == null
                        ? Icon(Icons.person, color: AppColors.mutedForeground, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: ' ${_verb(l10n)}'),
                            ],
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _relativeTime(l10n, event.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  if (badgeLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeLabel.toUpperCase(),
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (event.type == 'completed_exchange' && event.offeredBookTitle != null)
              _SwapBody(event: event)
            else
              _BookBody(event: event),
            if (event.type == 'completed_exchange' && event.offeredBookTitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  l10n.activitySwapCaption(
                    name,
                    event.bookTitle,
                    event.offeredBookTitle!,
                    event.counterpartyName ?? l10n.commonUnknownUser,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                ),
              )
            else if (event.caption != null && event.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$name: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: '"${event.caption}"'),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _BookBody extends StatelessWidget {
  const _BookBody({required this.event});
  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(url: event.bookCoverUrl, title: event.bookTitle, width: 84, height: 126),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.bookTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.foreground,
                  ),
                ),
                if (event.bookAuthor != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.bookAuthor!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
                if (event.genre != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      localizedGenre(context, event.genre!),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
                if (event.currentPage != null) ...[
                  const SizedBox(height: 8),
                  if (event.totalPages != null && event.totalPages! > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (event.currentPage! / event.totalPages!).clamp(0, 1),
                        minHeight: 4,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    event.totalPages != null
                        ? context.l10n.bookshelfProgressLabel(event.currentPage!, event.totalPages!)
                        : context.l10n.bookshelfProgressLabelNoTotal(event.currentPage!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwapBody extends StatelessWidget {
  const _SwapBody({required this.event});
  final ActivityEvent event;

  Widget _cover(BuildContext context, String title, String? url) {
    return Column(
      children: [
        BookCover(url: url, title: title, width: 96, height: 144),
        const SizedBox(height: 6),
        SizedBox(
          width: 110,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _cover(context, event.bookTitle, event.bookCoverUrl)),
          Padding(
            padding: const EdgeInsets.only(top: 52),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.muted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.swap_horiz, size: 18, color: AppColors.success),
            ),
          ),
          Expanded(child: _cover(context, event.offeredBookTitle!, event.offeredBookCoverUrl)),
        ],
      ),
    );
  }
}
