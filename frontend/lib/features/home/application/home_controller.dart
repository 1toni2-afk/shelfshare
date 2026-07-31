import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_book.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../books/data/books_repository.dart';

/// Feed-ul paginat al paginii principale: ultimele cărți postate (după
/// `createdAt`, NU `updatedAt` - ca userii să nu-și boosteze anunțul printr-un
/// simplu edit) cu trei secțiuni tematice injectate ca ancore vizuale între
/// rânduri: „Most Sought After" după 2 rânduri, „Close Near You" după alte 3,
/// „Recommended for you" după încă 3. Vezi kHomeSectionSlots.
class HomeFeedState {
  const HomeFeedState({
    this.recent = const [],
    this.mostViewed = const [],
    this.nearby = const [],
    this.recommended = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<UserBook> recent;
  final List<UserBook> mostViewed;

  /// Cărți disponibile la maxim [kNearbyRadiusKm] de orașul userului. Gol dacă
  /// userul nu are oraș setat în profil sau dacă nu e nimic în raza asta.
  final List<UserBook> nearby;

  /// Cărți recomandate content-based (genuri/autori derivați din profil și
  /// din bibliotecă). Gol dacă nu avem semnal - vezi endpointul.
  final List<UserBook> recommended;

  final bool isLoadingMore;
  final bool hasMore;

  HomeFeedState copyWith({
    List<UserBook>? recent,
    List<UserBook>? mostViewed,
    List<UserBook>? nearby,
    List<UserBook>? recommended,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return HomeFeedState(
      recent: recent ?? this.recent,
      mostViewed: mostViewed ?? this.mostViewed,
      nearby: nearby ?? this.nearby,
      recommended: recommended ?? this.recommended,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

const _pageSize = 12;

/// Raza secțiunii „Close Near You". Distanța se calculează între centrele
/// orașelor (vezi ROMANIAN_CITY_COORDINATES pe backend), deci e orientativă.
/// Am scăzut de la 50 km la 25 km ca „close" să însemne cu adevărat aproape,
/// nu jumătate de județ.
const kNearbyRadiusKm = 25;

/// Câte rânduri de „recent" preced fiecare secțiune tematică, în ordine.
/// Rândurile sunt calculate din numărul real de coloane afișate, deci pe
/// desktop cu 5 coloane [2, 3, 3] înseamnă 10, 15, 15 cărți; pe telefon cu 2
/// coloane, aceleași rânduri = 4, 6, 6 cărți.
const kHomeSectionSlots = [2, 3, 3];

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

    // Fiecare secțiune se cere în paralel; dacă una pică (ex. recommended
    // fără chestionar completat pe un backend vechi), restul feed-ului se
    // afișează normal iar secțiunea respectivă rămâne ascunsă. Cererile stau
    // pe futures separate ca `Future.wait` să nu împartă un tip generic.
    final hasCity = myCity != null && myCity.isNotEmpty;
    final recentFuture = repository.browse(sort: 'recent', limit: _pageSize, offset: 0);
    final trendingFuture = repository.browse(sort: 'mostViewed', limit: _pageSize, offset: 0)
        .then((r) => r.items)
        .catchError((_) => <UserBook>[]);
    final nearbyFuture = hasCity
        ? repository
            .browse(
              sort: 'distance',
              fromCity: myCity,
              maxDistanceKm: kNearbyRadiusKm,
              limit: _pageSize,
              offset: 0,
            )
            // Fără propriile anunțuri: sunt la 0 km de userul însuși, deci ar
            // ocupa începutul secțiunii fără să-i spună nimic nou.
            .then((r) => r.items.where((b) => b.userId != me?.id).toList())
            .catchError((_) => <UserBook>[])
        : Future.value(const <UserBook>[]);
    final recommendedFuture =
        repository.getRecommendedForYou().catchError((_) => <UserBook>[]);

    final recentResult = await recentFuture;
    return HomeFeedState(
      recent: recentResult.items,
      mostViewed: await trendingFuture,
      nearby: await nearbyFuture,
      recommended: await recommendedFuture,
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
