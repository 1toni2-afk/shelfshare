import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/app_notification.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/notifications_controller.dart';
import 'notification_routing.dart';

enum _Filter { all, unread, exchanges, messages }

const _exchangeTypes = {
  NotificationType.exchangeRequestReceived,
  NotificationType.exchangeRequestAccepted,
  NotificationType.exchangeRequestRejected,
  NotificationType.exchangeMeetingScheduled,
  NotificationType.exchangeMeetingProposed,
  NotificationType.exchangeMeetingAccepted,
  NotificationType.exchangeMeetingDeclined,
  NotificationType.exchangeContactShared,
  NotificationType.exchangeReady,
  NotificationType.exchangePostponed,
  NotificationType.exchangeDonePendingConfirmation,
  NotificationType.exchangeDoneDisputed,
  NotificationType.exchangeCompleted,
  NotificationType.exchangeCancelled,
  NotificationType.exchangeBookPending,
  NotificationType.exchangeReopened,
  NotificationType.priceOfferReceived,
  NotificationType.priceOfferAccepted,
  NotificationType.priceOfferRejected,
  NotificationType.outbid,
  NotificationType.auctionWon,
  NotificationType.auctionEnded,
};

/// O notificare vizuală: fie una singură din backend, fie un grup de
/// notificări identice consecutive (același tip + același text) colapsate
/// într-un singur rând - problema celor 8 rânduri "ai un mesaj nou" identice.
class _NotifGroup {
  _NotifGroup(AppNotification first)
      : items = [first],
        latest = first;

  final List<AppNotification> items;
  AppNotification latest;

  void add(AppNotification n) {
    items.add(n);
    if (n.createdAt.isAfter(latest.createdAt)) latest = n;
  }

  bool get isRead => items.every((n) => n.isRead);
  int get count => items.length;
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _Filter _filter = _Filter.all;

  List<_NotifGroup> _group(List<AppNotification> notifications) {
    final groups = <_NotifGroup>[];
    for (final n in notifications) {
      final prev = groups.isNotEmpty ? groups.last : null;
      if (prev != null &&
          prev.latest.type == n.type &&
          prev.latest.message == n.message &&
          prev.latest.createdAt.difference(n.createdAt).abs() < const Duration(hours: 12)) {
        prev.add(n);
      } else {
        groups.add(_NotifGroup(n));
      }
    }
    return groups;
  }

  List<_NotifGroup> _filtered(List<_NotifGroup> groups) {
    switch (_filter) {
      case _Filter.all:
        return groups;
      case _Filter.unread:
        return groups.where((g) => !g.isRead).toList();
      case _Filter.exchanges:
        return groups.where((g) => _exchangeTypes.contains(g.latest.type)).toList();
      case _Filter.messages:
        return groups.where((g) => g.latest.type == NotificationType.newMessage).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final all = state.value ?? const [];
    final hasUnread = all.any((n) => !n.isRead);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
          child: state.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return CenteredScrollable(child: Text(l10n.notificationsEmpty));
              }
              final groups = _filtered(_group(notifications));
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              if (hasUnread) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l10n.notificationsUnreadCount(all.where((n) => !n.isRead).length),
                                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ),
                                const Spacer(),
                              ] else
                                const Spacer(),
                              if (hasUnread)
                                TextButton(
                                  onPressed: () =>
                                      ref.read(notificationsControllerProvider.notifier).markAllAsRead(),
                                  child: Text(l10n.notificationsMarkAllRead),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterPill(
                                label: l10n.notificationsFilterAll,
                                selected: _filter == _Filter.all,
                                onTap: () => setState(() => _filter = _Filter.all),
                              ),
                              _FilterPill(
                                label: l10n.notificationsFilterUnread,
                                selected: _filter == _Filter.unread,
                                onTap: () => setState(() => _filter = _Filter.unread),
                              ),
                              _FilterPill(
                                label: l10n.notificationsFilterExchanges,
                                selected: _filter == _Filter.exchanges,
                                onTap: () => setState(() => _filter = _Filter.exchanges),
                              ),
                              _FilterPill(
                                label: l10n.notificationsFilterMessages,
                                selected: _filter == _Filter.messages,
                                onTap: () => setState(() => _filter = _Filter.messages),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (groups.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text(l10n.notificationsEmpty)),
                        )
                      else
                        ..._buildDayedSlivers(context, groups),
                    ],
                  ),
                ),
              );
            },
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.notificationsLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(notificationsControllerProvider.notifier).refresh(),
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Grupare pe zile (Astăzi / Ieri / Mai vechi) - fereastra „3h ago" repetată
  // pe fiecare rând devine un header o singură dată pe secțiune.
  List<Widget> _buildDayedSlivers(BuildContext context, List<_NotifGroup> groups) {
    final l10n = context.l10n;
    final now = DateTime.now();
    String bucketFor(DateTime t) {
      final local = t.toLocal();
      final diff = DateTime(now.year, now.month, now.day).difference(DateTime(local.year, local.month, local.day)).inDays;
      if (diff == 0) return l10n.notificationsToday;
      if (diff == 1) return l10n.notificationsYesterday;
      return l10n.notificationsEarlier;
    }

    final slivers = <Widget>[];
    String? currentBucket;
    for (final group in groups) {
      final bucket = bucketFor(group.latest.createdAt);
      if (bucket != currentBucket) {
        currentBucket = bucket;
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                bucket,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              ),
            ),
          ),
        );
      }
      slivers.add(
        SliverToBoxAdapter(
          child: _NotificationRow(group: group),
        ),
      );
    }
    return slivers;
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.accent : AppColors.mutedForeground,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.group});
  final _NotifGroup group;

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.wishlistBookAvailable:
        return Icons.favorite_border;
      case NotificationType.newMessage:
        return Icons.chat_bubble_outline;
      case NotificationType.exchangeRequestReceived:
      case NotificationType.exchangeRequestAccepted:
      case NotificationType.exchangeRequestRejected:
        return Icons.swap_horiz;
      case NotificationType.exchangeMeetingScheduled:
      case NotificationType.exchangeMeetingProposed:
      case NotificationType.exchangeMeetingAccepted:
      case NotificationType.exchangeMeetingDeclined:
      case NotificationType.exchangePostponed:
        return Icons.event;
      case NotificationType.exchangeContactShared:
        return Icons.contact_phone_outlined;
      case NotificationType.exchangeReady:
        return Icons.handshake_outlined;
      case NotificationType.exchangeDonePendingConfirmation:
      case NotificationType.exchangeCompleted:
        return Icons.task_alt;
      case NotificationType.exchangeDoneDisputed:
      case NotificationType.exchangeCancelled:
        return Icons.cancel_outlined;
      case NotificationType.exchangeBookPending:
      case NotificationType.exchangeReopened:
        return Icons.hourglass_empty;
      case NotificationType.priceOfferReceived:
      case NotificationType.priceOfferAccepted:
      case NotificationType.priceOfferRejected:
        return Icons.sell_outlined;
      case NotificationType.followedUserNewBook:
        return Icons.person_add_alt_outlined;
      case NotificationType.nearbyBookListed:
        return Icons.location_on_outlined;
      case NotificationType.interestBookListed:
        return Icons.auto_awesome_outlined;
      case NotificationType.unknown:
        return Icons.notifications_outlined;
      case NotificationType.priceChanged:
        return Icons.price_change_outlined;
      case NotificationType.outbid:
      case NotificationType.auctionWon:
      case NotificationType.auctionEnded:
        return Icons.gavel;
    }
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unread = !group.isRead;
    final latest = group.latest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: unread ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Marchează toate notificările colapsate în acest rând ca citite.
            for (final n in group.items) {
              if (!n.isRead) {
                ref.read(notificationsControllerProvider.notifier).markAsRead(n.id);
              }
            }
            openNotification(context, ref, latest);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 7, color: AppColors.accent),
                  )
                else
                  const SizedBox(width: 15),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.muted,
                  child: Icon(_iconFor(latest.type), size: 17, color: AppColors.mutedForeground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.count > 1
                            ? '${latest.message} ${l10n.notificationsRepeatedCount(group.count)}'
                            : latest.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _relativeTime(l10n, latest.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
