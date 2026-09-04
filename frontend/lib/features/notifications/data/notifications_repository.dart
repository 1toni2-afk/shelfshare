import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/notification_preferences.dart';

class NotificationsRepository {
  NotificationsRepository(this._ref);
  final Ref _ref;

  Future<List<AppNotification>> getNotifications() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/notifications');
    return (response.data as List<dynamic>)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/notifications/read-all');
  }

  Future<NotificationPreferences> getPreferences() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/notifications/preferences');
    return _parse(response.data);
  }

  /// PUT parțial: trimitem doar tipurile atinse, restul rămân neschimbate pe
  /// server. Răspunsul e harta completă de după scriere.
  Future<NotificationPreferences> setPreferences(
    NotificationPreferences changes,
  ) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.put('/notifications/preferences', data: {
      'preferences': [
        for (final entry in changes.entries)
          {'type': entry.key, 'enabled': entry.value},
      ],
    });
    return _parse(response.data);
  }

  NotificationPreferences _parse(dynamic data) {
    return {
      for (final entry in (data as Map<String, dynamic>).entries)
        entry.key: entry.value as bool,
    };
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref);
});
