import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_notification.dart';

/// Iconița reprezentativă pentru fiecare tip de notificare - folosită în
/// bulinele halo-ului (Batch 7).
IconData notificationIcon(NotificationType type) {
  switch (type) {
    case NotificationType.newMessage:
      return Icons.chat_bubble;
    case NotificationType.exchangeRequestReceived:
    case NotificationType.exchangeRequestAccepted:
    case NotificationType.exchangeRequestRejected:
    case NotificationType.exchangeMeetingScheduled:
      return Icons.swap_horiz;
    case NotificationType.priceOfferReceived:
    case NotificationType.priceOfferAccepted:
    case NotificationType.priceOfferRejected:
      return Icons.sell;
    case NotificationType.priceChanged:
      return Icons.price_change;
    case NotificationType.wishlistBookAvailable:
    case NotificationType.interestBookListed:
      return Icons.favorite;
    case NotificationType.followedUserNewBook:
      return Icons.person;
    case NotificationType.nearbyBookListed:
      return Icons.place;
    case NotificationType.outbid:
    case NotificationType.auctionWon:
    case NotificationType.auctionEnded:
      return Icons.gavel;
    case NotificationType.unknown:
      return Icons.notifications;
  }
}

/// Avatar cu notificările necitite dispuse ca buline pe un arc deasupra lui
/// (mockup Batch 7). Maxim [_maxBubbles] buline distincte; dacă sunt mai
/// multe, ultima devine un „+N" care duce la lista completă.
///
/// Poziționarea e trigonometrică: bulinele se distribuie egal pe un arc
/// centrat sus (de la stânga, peste vârf, spre dreapta), la [_radius] de
/// centrul avatarului.
class NotificationHalo extends StatelessWidget {
  const NotificationHalo({
    super.key,
    required this.notifications,
    required this.avatar,
    required this.onBubbleTap,
    required this.onOverflowTap,
    this.avatarRadius = 28,
  });

  /// Notificările de afișat ca buline (de regulă doar cele necitite).
  final List<AppNotification> notifications;

  /// Avatarul din centru.
  final Widget avatar;

  /// Tap pe o bulină individuală - deschide notificarea respectivă.
  final void Function(AppNotification notification) onBubbleTap;

  /// Tap pe bulina „+N" - duce la ecranul complet de notificări.
  final VoidCallback onOverflowTap;

  final double avatarRadius;

  static const _maxBubbles = 8;
  static const _bubbleRadius = 13.0;
  static const _radius = 46.0;

  @override
  Widget build(BuildContext context) {
    final unread = notifications;
    // Fără notificări: doar avatarul, fără halo. Nu ocupăm spațiu suplimentar.
    if (unread.isEmpty) {
      return SizedBox(
        height: avatarRadius * 2,
        child: Center(child: avatar),
      );
    }

    // Dacă depășim maximul, rezervăm ultima poziție pentru „+N".
    final hasOverflow = unread.length > _maxBubbles;
    final shown = hasOverflow ? unread.take(_maxBubbles - 1).toList() : unread;
    final overflowCount = unread.length - shown.length;
    final bubbleCount = shown.length + (hasOverflow ? 1 : 0);

    // Dimensiunea zonei: avatar în centru + rază + diametrul unei buline.
    final extent = (_radius + _bubbleRadius) * 2;
    final center = extent / 2;

    // Arc centrat sus: de la 200° la 340° (măsurat standard, cu Y în jos în
    // Flutter, deci „sus" e la -90° = 270°). Distribuim egal; o singură
    // bulină stă fix deasupra.
    const startDeg = 200.0;
    const endDeg = 340.0;

    final bubbles = <Widget>[];
    for (var i = 0; i < bubbleCount; i++) {
      final t = bubbleCount == 1 ? 0.5 : i / (bubbleCount - 1);
      final angleDeg = startDeg + (endDeg - startDeg) * t;
      final angleRad = angleDeg * math.pi / 180;
      final dx = center + _radius * math.cos(angleRad) - _bubbleRadius;
      final dy = center + _radius * math.sin(angleRad) - _bubbleRadius;

      final isOverflowBubble = hasOverflow && i == bubbleCount - 1;
      bubbles.add(Positioned(
        left: dx,
        top: dy,
        child: isOverflowBubble
            ? _OverflowBubble(count: overflowCount, onTap: onOverflowTap)
            : _NotificationBubble(
                notification: shown[i],
                onTap: () => onBubbleTap(shown[i]),
              ),
      ));
    }

    return SizedBox(
      width: extent,
      height: extent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.center, child: avatar),
          ...bubbles,
        ],
      ),
    );
  }
}

class _NotificationBubble extends StatelessWidget {
  const _NotificationBubble({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: notification.message,
        child: Container(
          width: NotificationHalo._bubbleRadius * 2,
          height: NotificationHalo._bubbleRadius * 2,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.card, width: 2),
          ),
          child: Icon(
            notificationIcon(notification.type),
            size: 13,
            color: AppColors.accentForeground,
          ),
        ),
      ),
    );
  }
}

class _OverflowBubble extends StatelessWidget {
  const _OverflowBubble({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: NotificationHalo._bubbleRadius * 2,
        height: NotificationHalo._bubbleRadius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.muted,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.card, width: 2),
        ),
        child: Text(
          '+$count',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
