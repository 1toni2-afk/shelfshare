import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_notification.dart';
import '../data/notifications_repository.dart';

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    return ref.read(notificationsRepositoryProvider).getNotifications();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(notificationsRepositoryProvider).getNotifications());
  }

  Future<void> markAsRead(String id) async {
    final current = state.value ?? const [];
    final matches = current.where((n) => n.id == id);
    if (matches.isEmpty || matches.first.isRead) return;

    await ref.read(notificationsRepositoryProvider).markAsRead(id);
    state = AsyncData([
      for (final n in current)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);
  }

  Future<void> markAllAsRead() async {
    final current = state.value ?? const [];
    if (current.every((n) => n.isRead)) return;

    await ref.read(notificationsRepositoryProvider).markAllAsRead();
    state = AsyncData([for (final n in current) n.copyWith(isRead: true)]);
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);
