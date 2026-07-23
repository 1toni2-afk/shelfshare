import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user_book.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/books_repository.dart';

class BrowseFilters {
  const BrowseFilters({
    this.title,
    this.author,
    this.genre,
    this.language,
    this.city,
    this.condition,
    this.maxDistanceKm,
    this.listingType,
  });

  final String? title;
  final String? author;
  final String? genre;
  final String? language;
  final String? city;
  final BookCondition? condition;
  final int? maxDistanceKm;
  final String? listingType;

  bool get hasActiveFilters =>
      author != null ||
      genre != null ||
      language != null ||
      city != null ||
      condition != null ||
      maxDistanceKm != null ||
      listingType != null;

  BrowseFilters withTitle(String? title) {
    return BrowseFilters(
      title: title,
      author: author,
      genre: genre,
      language: language,
      city: city,
      condition: condition,
      maxDistanceKm: maxDistanceKm,
      listingType: listingType,
    );
  }
}

class BrowseState {
  const BrowseState({
    this.filters = const BrowseFilters(),
    this.items = const [],
    this.total = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasError = false,
  });

  final BrowseFilters filters;
  final List<UserBook> items;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasError;

  bool get hasMore => items.length < total;

  BrowseState copyWith({
    BrowseFilters? filters,
    List<UserBook>? items,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasError,
  }) {
    return BrowseState(
      filters: filters ?? this.filters,
      items: items ?? this.items,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
    );
  }
}

class BrowseController extends Notifier<BrowseState> {
  static const _pageSize = 20;

  @override
  BrowseState build() {
    _search(const BrowseFilters());
    return const BrowseState();
  }

  Future<void> _search(BrowseFilters filters) async {
    state = BrowseState(filters: filters, isLoading: true);
    try {
      final result = await _fetch(filters, offset: 0);
      state = BrowseState(filters: filters, items: result.items, total: result.total, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  Future<BrowseResult> _fetch(BrowseFilters f, {required int offset}) {
    final repository = ref.read(booksRepositoryProvider);
    final authState = ref.read(authControllerProvider);
    final myCity = authState is AuthAuthenticated ? authState.user.city : null;
    final sortingByDistance = f.maxDistanceKm != null && myCity != null && myCity.isNotEmpty;

    return repository.browse(
      title: f.title,
      author: f.author,
      genre: f.genre,
      language: f.language,
      city: f.city,
      condition: f.condition?.toJson(),
      sort: sortingByDistance ? 'distance' : null,
      fromCity: sortingByDistance ? myCity : null,
      maxDistanceKm: sortingByDistance ? f.maxDistanceKm : null,
      listingType: f.listingType,
      limit: _pageSize,
      offset: offset,
    );
  }

  Future<void> updateTitle(String? title) => _search(state.filters.withTitle(title));

  Future<void> applyFilters(BrowseFilters filters) => _search(filters);

  Future<void> retry() => _search(state.filters);

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _fetch(state.filters, offset: state.items.length);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final browseControllerProvider = NotifierProvider<BrowseController, BrowseState>(
  BrowseController.new,
);
