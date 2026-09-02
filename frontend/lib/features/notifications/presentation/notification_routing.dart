import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_route.dart';
import '../../../data/models/app_notification.dart';
import '../application/notifications_controller.dart';

/// Marchează notificarea ca citită și navighează la destinația potrivită
/// tipului ei. Partajat între ecranul de notificări și halo-ul din header
/// (Batch 7), ca logica de rutare să existe într-un singur loc.
///
/// Tabelul de destinații stă în `core/notifications/notification_route.dart`,
/// nu aici: aceeași rută trebuie calculată și la tap-ul pe o notificare de
/// sistem, unde nu există `BuildContext`.
void openNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
) {
  ref.read(notificationsControllerProvider.notifier).markAsRead(notification.id);
  final route = routeForNotification(notification.type, notification.data);
  if (route != null) context.push(route);
}
