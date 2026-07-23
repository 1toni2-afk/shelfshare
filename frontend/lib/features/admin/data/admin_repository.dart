import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/upcoming_release.dart';

class AdminRepository {
  AdminRepository(this._ref);
  final Ref _ref;

  Future<AdminStats> getStats() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/stats');
    return AdminStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MarketplaceStats> getMarketplaceStats() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/stats/marketplace');
    return MarketplaceStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ActiveZone>> getActiveZones() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/stats/active-zones');
    return (response.data as List).map((e) => ActiveZone.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminUsersPage> getUsers({int limit = 50, int offset = 0}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/admin/users',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return AdminUsersPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> banUser(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/admin/users/$userId/ban');
  }

  Future<void> unbanUser(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/admin/users/$userId/unban');
  }

  Future<void> togglePremium(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/admin/users/$userId/toggle-premium');
  }

  Future<void> deleteUser(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/admin/users/$userId');
  }

  Future<void> deleteUserBook(String userBookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/admin/user-books/$userBookId');
  }

  Future<List<InactiveListing>> getInactiveListings() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/reports/inactive-listings');
    return (response.data as List)
        .map((e) => InactiveListing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserReport>> getUserReports() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/reports/users');
    return (response.data as List)
        .map((e) => UserReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UpcomingRelease>> getUpcomingReleases() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/upcoming-releases');
    return (response.data as List)
        .map((e) => UpcomingRelease.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createUpcomingRelease({
    required String title,
    String? author,
    String? coverUrl,
    String? description,
    required DateTime releaseDate,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/upcoming-releases', data: {
      'title': title,
      if (author != null && author.isNotEmpty) 'author': author,
      if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
      if (description != null && description.isNotEmpty) 'description': description,
      'releaseDate': releaseDate.toIso8601String(),
    });
  }

  Future<void> deleteUpcomingRelease(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/upcoming-releases/$id');
  }

  Future<List<FeedbackItem>> getFeedback() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/feedback');
    return (response.data as List)
        .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SupportRequestItem>> getSupportRequests() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/support-requests');
    return (response.data as List)
        .map((e) => SupportRequestItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref);
});
