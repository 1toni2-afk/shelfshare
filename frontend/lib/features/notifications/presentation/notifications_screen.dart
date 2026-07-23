import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/app_notification.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _openNotification(BuildContext context, WidgetRef ref, AppNotification notification) {
    ref.read(notificationsControllerProvider.notifier).markAsRead(notification.id);
    switch (notification.type) {
      case NotificationType.wishlistBookAvailable:
        context.push('/wishlist');
      case NotificationType.newMessage:
        final conversationId = notification.data?['conversationId'] as String?;
        if (conversationId != null) {
          context.push('/chat/$conversationId');
        }
      case NotificationType.exchangeRequestReceived:
      case NotificationType.exchangeRequestAccepted:
      case NotificationType.exchangeRequestRejected:
      case NotificationType.exchangeMeetingScheduled:
        context.push('/exchanges');
      case NotificationType.priceOfferReceived:
      case NotificationType.priceOfferAccepted:
      case NotificationType.priceOfferRejected:
        // Oferta e vizibilă și acționabilă direct în chat (vezi Message.priceOfferId) -
        // trimitem acolo, nu la ecranul separat de schimburi. Notificările vechi
        // (create înainte de acest fix) n-au conversationId - fallback la /exchanges.
        final conversationId = notification.data?['conversationId'] as String?;
        if (conversationId != null) {
          context.push('/chat/$conversationId');
        } else {
          context.push('/exchanges');
        }
      case NotificationType.followedUserNewBook:
        final userId = notification.data?['userId'] as String?;
        if (userId != null) {
          context.push('/users/$userId');
        }
      case NotificationType.nearbyBookListed:
        context.push('/search');
      case NotificationType.priceChanged:
        context.push('/wishlist');
      case NotificationType.outbid:
      case NotificationType.auctionWon:
      case NotificationType.auctionEnded:
        final auctionId = notification.data?['auctionId'] as String?;
        if (auctionId != null) {
          context.push('/auctions/$auctionId');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final hasUnread = (state.value ?? const []).any((n) => !n.isRead);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => ref.read(notificationsControllerProvider.notifier).markAllAsRead(),
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
          child: state.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return CenteredScrollable(child: Text(l10n.notificationsEmpty));
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return ListTile(
                    leading: Icon(_iconFor(notification.type)),
                    title: Text(notification.message),
                    subtitle: Text(_relativeTime(l10n, notification.createdAt)),
                    tileColor: notification.isRead ? null : AppColors.accent.withValues(alpha: 0.08),
                    trailing: notification.isRead
                        ? null
                        : const Icon(Icons.circle, size: 10, color: AppColors.accent),
                    onTap: () => _openNotification(context, ref, notification),
                  );
                },
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
        return Icons.event;
      case NotificationType.priceOfferReceived:
      case NotificationType.priceOfferAccepted:
      case NotificationType.priceOfferRejected:
        return Icons.sell_outlined;
      case NotificationType.followedUserNewBook:
        return Icons.person_add_alt_outlined;
      case NotificationType.nearbyBookListed:
        return Icons.location_on_outlined;
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
}
