import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/upcoming_release.dart';
import '../data/admin_repository.dart';

class AdminData {
  const AdminData({
    required this.stats,
    required this.marketplaceStats,
    required this.activeZones,
    required this.users,
    required this.inactiveListings,
    required this.userReports,
    required this.upcomingReleases,
    required this.feedback,
    required this.supportRequests,
  });
  final AdminStats stats;
  final MarketplaceStats marketplaceStats;
  final List<ActiveZone> activeZones;
  final AdminUsersPage users;
  final List<InactiveListing> inactiveListings;
  final List<UserReport> userReports;
  final List<UpcomingRelease> upcomingReleases;
  final List<FeedbackItem> feedback;
  final List<SupportRequestItem> supportRequests;

  AdminData copyWith({
    AdminUsersPage? users,
    List<InactiveListing>? inactiveListings,
    List<UpcomingRelease>? upcomingReleases,
  }) {
    return AdminData(
      stats: stats,
      marketplaceStats: marketplaceStats,
      activeZones: activeZones,
      users: users ?? this.users,
      inactiveListings: inactiveListings ?? this.inactiveListings,
      userReports: userReports,
      upcomingReleases: upcomingReleases ?? this.upcomingReleases,
      feedback: feedback,
      supportRequests: supportRequests,
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

  void _updateUserLocally(String userId, {required bool isBanned}) {
    final current = state.value;
    if (current == null) return;
    final updatedItems = [
      for (final u in current.users.items)
        if (u.id == userId) u.copyWith(isBanned: isBanned) else u,
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
