import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/upcoming_release.dart';
import '../data/admin_repository.dart';

class AdminData {
  const AdminData({
    required this.stats,
    required this.statsHistory,
    required this.marketplaceStats,
    required this.activeZones,
    required this.users,
    required this.inactiveListings,
    required this.userReports,
    required this.upcomingReleases,
    required this.feedback,
    required this.supportRequests,
    required this.conversionFunnel,
  });
  final AdminStats stats;
  final List<StatsSnapshotPoint> statsHistory;
  final MarketplaceStats marketplaceStats;
  final List<ActiveZone> activeZones;
  final AdminUsersPage users;
  final List<InactiveListing> inactiveListings;
  final List<UserReport> userReports;
  final List<UpcomingRelease> upcomingReleases;
  final List<FeedbackItem> feedback;
  final List<SupportRequestItem> supportRequests;
  final ConversionFunnel conversionFunnel;

  AdminData copyWith({
    AdminUsersPage? users,
    List<InactiveListing>? inactiveListings,
    List<UpcomingRelease>? upcomingReleases,
    List<UserReport>? userReports,
  }) {
    return AdminData(
      stats: stats,
      statsHistory: statsHistory,
      marketplaceStats: marketplaceStats,
      activeZones: activeZones,
      users: users ?? this.users,
      inactiveListings: inactiveListings ?? this.inactiveListings,
      userReports: userReports ?? this.userReports,
      upcomingReleases: upcomingReleases ?? this.upcomingReleases,
      feedback: feedback,
      supportRequests: supportRequests,
      conversionFunnel: conversionFunnel,
    );
  }
}

class AdminController extends AsyncNotifier<AdminData> {
  @override
  Future<AdminData> build() => _load();

  Future<AdminData> _load() async {
    final repository = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repository.getStats(),
      repository.getMarketplaceStats(),
      repository.getActiveZones(),
      repository.getUsers(),
      repository.getInactiveListings(),
      repository.getUserReports(),
      repository.getUpcomingReleases(),
      repository.getFeedback(),
      repository.getSupportRequests(),
      repository.getStatsHistory(),
      repository.getConversionFunnel(),
    ]);
    return AdminData(
      stats: results[0] as AdminStats,
      marketplaceStats: results[1] as MarketplaceStats,
      activeZones: results[2] as List<ActiveZone>,
      users: results[3] as AdminUsersPage,
      inactiveListings: results[4] as List<InactiveListing>,
      userReports: results[5] as List<UserReport>,
      upcomingReleases: results[6] as List<UpcomingRelease>,
      feedback: results[7] as List<FeedbackItem>,
      supportRequests: results[8] as List<SupportRequestItem>,
      statsHistory: results[9] as List<StatsSnapshotPoint>,
      conversionFunnel: results[10] as ConversionFunnel,
    );
  }

  Future<void> createUpcomingRelease({
    required String title,
    String? author,
    String? coverUrl,
    String? description,
    required DateTime releaseDate,
  }) async {
    await ref.read(adminRepositoryProvider).createUpcomingRelease(
          title: title,
          author: author,
          coverUrl: coverUrl,
          description: description,
          releaseDate: releaseDate,
        );
    await refresh();
  }

  Future<void> deleteUpcomingRelease(String id) async {
    await ref.read(adminRepositoryProvider).deleteUpcomingRelease(id);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(upcomingReleases: current.upcomingReleases.where((r) => r.id != id).toList()),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> banUser(String userId) async {
    await ref.read(adminRepositoryProvider).banUser(userId);
    _updateUserLocally(userId, isBanned: true);
  }

  Future<void> unbanUser(String userId) async {
    await ref.read(adminRepositoryProvider).unbanUser(userId);
    _updateUserLocally(userId, isBanned: false);
  }

  Future<void> togglePremium(String userId, {required bool currentValue}) async {
    await ref.read(adminRepositoryProvider).togglePremium(userId);
    _updateUserLocally(userId, isPremium: !currentValue);
  }

  Future<void> deleteUser(String userId) async {
    await ref.read(adminRepositoryProvider).deleteUser(userId);
    await refresh();
  }

  Future<void> deleteUserBook(String userBookId) async {
    await ref.read(adminRepositoryProvider).deleteUserBook(userBookId);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(inactiveListings: current.inactiveListings.where((l) => l.id != userBookId).toList()),
    );
  }

  Future<void> updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? resolutionNote,
  }) async {
    final updated = await ref
        .read(adminRepositoryProvider)
        .updateReportStatus(reportId, status, resolutionNote: resolutionNote);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        userReports: [
          for (final r in current.userReports)
            if (r.id == reportId) updated else r,
        ],
      ),
    );
  }

  Future<void> deleteReportedGroupPost(String groupPostId) async {
    await ref.read(adminRepositoryProvider).deleteGroupPost(groupPostId);
    await refresh();
  }

  Future<void> deleteReportedReview(String reviewId) async {
    await ref.read(adminRepositoryProvider).deleteReview(reviewId);
    await refresh();
  }

  void _updateUserLocally(String userId, {bool? isBanned, bool? isPremium}) {
    final current = state.value;
    if (current == null) return;
    final updatedItems = [
      for (final u in current.users.items)
        if (u.id == userId) u.copyWith(isBanned: isBanned, isPremium: isPremium) else u,
    ];
    state = AsyncData(
      current.copyWith(
        users: AdminUsersPage(items: updatedItems, limit: current.users.limit, offset: current.users.offset),
      ),
    );
  }
}

final adminControllerProvider = AsyncNotifierProvider<AdminController, AdminData>(
  AdminController.new,
);
