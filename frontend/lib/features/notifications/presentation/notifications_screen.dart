import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
      case NotificationType.priceOfferReceived:
      case NotificationType.priceOfferAccepted:
      case NotificationType.priceOfferRejected:
        context.push('/exchanges');
      case NotificationType.followedUserNewBook:
        final userId = notification.data?['userId'] as String?;
        if (userId != null) {
          context.push('/users/$userId');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final hasUnread = (state.value ?? const []).any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificări'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => ref.read(notificationsControllerProvider.notifier).markAllAsRead(),
              child: const Text('Marchează tot ca citit'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
          child: state.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return const CenteredScrollable(child: Text('Nu ai nicio notificare.'));
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
                    subtitle: Text(_relativeTime(notification.createdAt)),
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
                  const Text('Nu am putut încărca notificările.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(notificationsControllerProvider.notifier).refresh(),
                    child: const Text('Încearcă din nou'),
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
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'acum';
    if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'acum ${diff.inHours} h';
    if (diff.inDays < 7) return 'acum ${diff.inDays} zile';
    return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}';
  }
}
