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

  Future<List<StatsSnapshotPoint>> getStatsHistory({int days = 30}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/stats/history', queryParameters: {'days': days});
    return (response.data as List).map((e) => StatsSnapshotPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ConversionFunnel> getConversionFunnel() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/stats/conversion-funnel');
    return ConversionFunnel.fromJson(response.data as Map<String, dynamic>);
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

  Future<List<AdminUser>> searchUsers(String query) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/admin/users/search',
      queryParameters: {'q': query},
    );
    return (response.data as List)
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserFeatureFlags> getUserFeatureFlags(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/users/$userId/feature-flags');
    return UserFeatureFlags.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserFeatureFlags> setUserFeatureFlags(
    String userId,
    List<FeatureFlagValue> flags,
  ) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.put(
      '/admin/users/$userId/feature-flags',
      data: {'flags': flags.map((f) => f.toJson()).toList()},
    );
    return UserFeatureFlags.fromJson(response.data as Map<String, dynamic>);
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

  Future<List<Administrator>> getAdministrators() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/administrators');
    return (response.data as List)
        .map((e) => Administrator.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Administrator> grantAdminRole(String userId, String roleId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post(
      '/admin/administrators',
      data: {'userId': userId, 'roleId': roleId},
    );
    return Administrator.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Administrator> updateAdminRole(String userId, String roleId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.put(
      '/admin/administrators/$userId/role',
      data: {'roleId': roleId},
    );
    return Administrator.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> revokeAdmin(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/admin/administrators/$userId');
  }

  Future<AdminRolesPage> getRoles() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/roles');
    return AdminRolesPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminRole> createCustomRole(String label, List<String> permissions) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post(
      '/admin/roles',
      data: {'label': label, 'permissions': permissions},
    );
    return AdminRole.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminRole> updateCustomRole(String roleId, String label, List<String> permissions) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.put(
      '/admin/roles/$roleId',
      data: {'label': label, 'permissions': permissions},
    );
    return AdminRole.fromJson(response.data as Map<String, dynamic>);
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

  Future<UserReport> updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? resolutionNote,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.put(
      '/admin/reports/$reportId/status',
      data: {
        'status': status.toJson(),
        if (resolutionNote != null && resolutionNote.isNotEmpty) 'resolutionNote': resolutionNote,
      },
    );
    return UserReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteGroupPost(String groupPostId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/admin/group-posts/$groupPostId');
  }

  Future<void> deleteReview(String reviewId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/admin/reviews/$reviewId');
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

  Future<ListingScoreBreakdown> getListingScore(String userBookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/admin/listings/$userBookId/score');
    return ListingScoreBreakdown.fromJson(response.data as Map<String, dynamic>);
  }

  /// `score: null` elimină overrideul și revine la scorul calculat.
  Future<ListingScoreBreakdown> setListingScoreOverride(
    String userBookId,
    double? score,
  ) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.put(
      '/admin/listings/$userBookId/score-override',
      data: {'score': score},
    );
    return ListingScoreBreakdown.fromJson(response.data as Map<String, dynamic>);
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
