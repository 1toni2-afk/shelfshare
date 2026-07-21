import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/upcoming_release.dart';
import '../data/admin_repository.dart';

class AdminData {
  const AdminData({
    required this.stats,
    required this.users,
    required this.inactiveListings,
    required this.userReports,
    required this.upcomingReleases,
    required this.feedback,
  });
  final AdminStats stats;
  final AdminUsersPage users;
  final List<InactiveListing> inactiveListings;
  final List<UserReport> userReports;
  final List<UpcomingRelease> upcomingReleases;
  final List<FeedbackItem> feedback;
}

class AdminController extends AsyncNotifier<AdminData> {
  @override
  Future<AdminData> build() => _load();

  Future<AdminData> _load() async {
    final repository = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repository.getStats(),
      repository.getUsers(),
      repository.getInactiveListings(),
      repository.getUserReports(),
      repository.getUpcomingReleases(),
      repository.getFeedback(),
    ]);
    return AdminData(
      stats: results[0] as AdminStats,
      users: results[1] as AdminUsersPage,
      inactiveListings: results[2] as List<InactiveListing>,
      userReports: results[3] as List<UserReport>,
      upcomingReleases: results[4] as List<UpcomingRelease>,
      feedback: results[5] as List<FeedbackItem>,
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
      AdminData(
        stats: current.stats,
        users: current.users,
        inactiveListings: current.inactiveListings,
        userReports: current.userReports,
        upcomingReleases: current.upcomingReleases.where((r) => r.id != id).toList(),
        feedback: current.feedback,
      ),
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
      AdminData(
        stats: current.stats,
        users: current.users,
        inactiveListings:
            current.inactiveListings.where((l) => l.id != userBookId).toList(),
        userReports: current.userReports,
        upcomingReleases: current.upcomingReleases,
        feedback: current.feedback,
      ),
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
      AdminData(
        stats: current.stats,
        users: AdminUsersPage(
          items: updatedItems,
          limit: current.users.limit,
          offset: current.users.offset,
        ),
        inactiveListings: current.inactiveListings,
        userReports: current.userReports,
        upcomingReleases: current.upcomingReleases,
        feedback: current.feedback,
      ),
    );
  }
}

final adminControllerProvider = AsyncNotifierProvider<AdminController, AdminData>(
  AdminController.new,
);
