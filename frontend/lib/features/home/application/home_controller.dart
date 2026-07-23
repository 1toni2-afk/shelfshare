import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/upcoming_release.dart';
import '../../../data/models/user.dart';
import '../../../data/models/user_book.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../books/data/books_repository.dart';
import '../../profile/data/follow_repository.dart';
import '../data/upcoming_releases_repository.dart';

class HomeData {
  const HomeData({
    required this.recent,
    required this.mostViewed,
    required this.nearby,
    required this.nearbyToday,
    required this.upcomingReleases,
    required this.genres,
    required this.activeMembers,
  });
  final List<UserBook> recent;
  final List<UserBook> mostViewed;
  final List<UserBook> nearby;
  final List<UserBook> nearbyToday;
  final List<UpcomingRelease> upcomingReleases;
  final List<BookGenre> genres;
  final List<PublicUser> activeMembers;
}

class HomeController extends AsyncNotifier<HomeData> {
  @override
  Future<HomeData> build() => _load();

  Future<HomeData> _load() async {
    final repository = ref.read(booksRepositoryProvider);
    final upcomingReleasesRepository =
        ref.read(upcomingReleasesRepositoryProvider);
    final authState = ref.read(authControllerProvider);
    final city = authState is AuthAuthenticated ? authState.user.city : null;

    // Pornim toate cererile în paralel - nu așteptăm una după alta.
    final booksResultsFuture = Future.wait([
      repository.browse(limit: 10),
      repository.browse(sort: 'mostViewed', limit: 10),
      if (city != null && city.isNotEmpty) repository.browse(city: city, limit: 10),
    ]);
    final upcomingReleasesFuture = upcomingReleasesRepository.list();
    final genresFuture = repository.getGenres();
    final activeMembersFuture = ref.read(followRepositoryProvider).getActiveMembers();
    final nearbyTodayFuture =
        city != null && city.isNotEmpty ? repository.getNearbyToday(city) : Future.value(<UserBook>[]);

    final results = await booksResultsFuture;
    final upcomingReleases = await upcomingReleasesFuture;
    final genres = await genresFuture;
    final activeMembers = await activeMembersFuture;
    final nearbyToday = await nearbyTodayFuture;

    return HomeData(
      recent: results[0].items,
      mostViewed: results[1].items,
      nearby: results.length > 2 ? results[2].items : const [],
      nearbyToday: nearbyToday,
      upcomingReleases: upcomingReleases,
      genres: genres,
      activeMembers: activeMembers,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeData>(
  HomeController.new,
);
