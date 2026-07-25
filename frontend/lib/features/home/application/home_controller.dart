import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_book.dart';
import '../../books/data/books_repository.dart';

/// Feed-ul paginat al paginii principale: ultimele cărți postate (după
/// `createdAt`, NU `updatedAt` - ca userii să nu-și boosteze anunțul printr-un
/// simplu edit) + un carusel „Cele mai căutate" injectat după primele 12.
class HomeFeedState {
  const HomeFeedState({
    this.recent = const [],
    this.mostViewed = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<UserBook> recent;
  final List<UserBook> mostViewed;
  final bool isLoadingMore;
  final bool hasMore;

  HomeFeedState copyWith({
    List<UserBook>? recent,
    List<UserBook>? mostViewed,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return HomeFeedState(
      recent: recent ?? this.recent,
      mostViewed: mostViewed ?? this.mostViewed,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

const _pageSize = 12;

class HomeController extends AsyncNotifier<HomeFeedState> {
  @override
  Future<HomeFeedState> build() => _loadInitial();

  Future<HomeFeedState> _loadInitial() async {
    final repository = ref.read(booksRepositoryProvider);
    // Prima pagină de recente + trending, în paralel.
    final results = await Future.wait([
      repository.browse(sort: 'recent', limit: _pageSize, offset: 0),
      repository.browse(sort: 'mostViewed', limit: _pageSize, offset: 0),
    ]);
    final recentResult = results[0];
    final mostViewedResult = results[1];
    return HomeFeedState(
      recent: recentResult.items,
      mostViewed: mostViewedResult.items,
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
