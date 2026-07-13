import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/app_notification.dart';

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
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref);
});
