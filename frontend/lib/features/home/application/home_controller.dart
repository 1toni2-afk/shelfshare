import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_book.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../books/data/books_repository.dart';

/// Feed-ul paginat al paginii principale: ultimele cărți postate (după
/// `createdAt`, NU `updatedAt` - ca userii să nu-și boosteze anunțul printr-un
/// simplu edit) + un carusel „Cele mai căutate" injectat după primele 12.
class HomeFeedState {
  const HomeFeedState({
    this.recent = const [],
    this.mostViewed = const [],
    this.nearby = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<UserBook> recent;
  final List<UserBook> mostViewed;

  /// Cărți disponibile la maxim [kNearbyRadiusKm] de orașul userului. Gol dacă
  /// userul nu are oraș setat în profil sau dacă nu e nimic în raza asta.
  final List<UserBook> nearby;
  final bool isLoadingMore;
  final bool hasMore;

  HomeFeedState copyWith({
    List<UserBook>? recent,
    List<UserBook>? mostViewed,
    List<UserBook>? nearby,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return HomeFeedState(
      recent: recent ?? this.recent,
      mostViewed: mostViewed ?? this.mostViewed,
      nearby: nearby ?? this.nearby,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

const _pageSize = 12;

/// Raza secțiunii „cărți în jurul tău". Distanța se calculează între centrele
/// orașelor (vezi ROMANIAN_CITY_COORDINATES pe backend), deci e orientativă.
const kNearbyRadiusKm = 50;

class HomeController extends AsyncNotifier<HomeFeedState> {
  @override
  Future<HomeFeedState> build() => _loadInitial();

  Future<HomeFeedState> _loadInitial() async {
    final repository = ref.read(booksRepositoryProvider);
    // Orașul din profil e originea pentru „în jurul tău". Fără oraș setat nu
    // avem de unde calcula distanța, deci sărim peste cerere.
    final auth = ref.read(authControllerProvider);
    final me = auth is AuthAuthenticated ? auth.user : null;
    final myCity = me?.city;

    // Prima pagină de recente + trending + vecinătate, în paralel.
    final results = await Future.wait([
      repository.browse(sort: 'recent', limit: _pageSize, offset: 0),
      repository.browse(sort: 'mostViewed', limit: _pageSize, offset: 0),
      if (myCity != null && myCity.isNotEmpty)
        repository.browse(
          sort: 'distance',
          fromCity: myCity,
          maxDistanceKm: kNearbyRadiusKm,
          limit: _pageSize,
          offset: 0,
        ),
    ]);
    final recentResult = results[0];
    final mostViewedResult = results[1];
    return HomeFeedState(
      recent: recentResult.items,
      mostViewed: mostViewedResult.items,
      // Fără propriile anunțuri: ele sunt la 0 km de userul însuși, deci ar
      // ocupa începutul secțiunii „în jurul tău" fără să-i spună nimic nou.
      nearby: results.length > 2
          ? results[2].items.where((b) => b.userId != me?.id).toList()
          : const [],
      hasMore: recentResult.items.length < recentResult.total,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repository = ref.read(booksRepositoryProvider);
      final result = await repository.browse(
        sort: 'recent',
        limit: _pageSize,
        offset: current.recent.length,
      );
      final merged = [...current.recent, ...result.items];
      state = AsyncData(current.copyWith(
        recent: merged,
        isLoadingMore: false,
        hasMore: merged.length < result.total && result.items.isNotEmpty,
      ));
    } catch (_) {
      // Nu dărâmăm tot feed-ul pentru o pagină eșuată - doar oprim spinner-ul,
      // userul poate reîncerca dând scroll din nou.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadInitial);
  }
}

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeFeedState>(
  HomeController.new,
);
