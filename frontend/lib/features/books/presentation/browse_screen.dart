import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_grid_metrics.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/browse_controller.dart';
import '../data/books_repository.dart';
import 'browse_filters_sheet.dart';

final _popularSearchesProvider = FutureProvider((ref) {
  return ref.watch(booksRepositoryProvider).getPopularSearches();
});

/// Argumente opționale trimise ecranului de căutare din alte ecrane (ex.
/// wishlist trimite un titlu, Home trimite un gen din secțiunea Categorii).
class SearchScreenArgs {
  const SearchScreenArgs({
    this.title,
    this.author,
    this.genre,
    this.listingType,
    this.city,
    this.sort,
  });
  final String? title;
  final String? author;
  final String? genre;
  /// „swap" / „sale" / „auction" / „donation" - folosit de sheet-ul
  /// „Filtrează" din Discover.
  final String? listingType;
  final String? city;
  /// „popularity" / „recent" / „oldest" / „distance" - sheet-ul „Sortează"
  /// din Discover. „distance" are efect doar dacă userul are oraș setat în
  /// profil.
  final String? sort;
}

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({
    super.key,
    this.initialTitle,
    this.initialAuthor,
    this.initialGenre,
    this.initialListingType,
    this.initialCity,
    this.initialSort,
  });
  final String? initialTitle;
  final String? initialAuthor;
  final String? initialGenre;
  final String? initialListingType;
  final String? initialCity;
  final String? initialSort;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  // Câmpul de căutare afișează titlul SAU autorul, orice a fost dat ca
  // preset - dar filtrul aplicat efectiv respectă exact ce a fost cerut
  // (vezi mai jos): un autor merge pe `BrowseFilters.author`, nu pe
  // `title`, altfel căutarea nu se restrângea deloc la cărțile lui (bug:
  // click pe autor din detaliul cărții afișa toate cărțile, nu doar ale lui).
  late final _searchController =
      TextEditingController(text: widget.initialTitle ?? widget.initialAuthor);
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Aplicăm filtrele initiale ca un singur update - dacă vin mai multe
    // (ex. „Doar la schimb" din orașul tău), le combinăm într-un singur
    // `BrowseFilters`, altfel al doilea l-ar suprascrie pe primul.
    final hasPreset = (widget.initialAuthor?.isNotEmpty ?? false) ||
        (widget.initialGenre?.isNotEmpty ?? false) ||
        (widget.initialListingType?.isNotEmpty ?? false) ||
        (widget.initialCity?.isNotEmpty ?? false) ||
        (widget.initialSort?.isNotEmpty ?? false);
    if (hasPreset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(browseControllerProvider.notifier).applyFilters(BrowseFilters(
              author: widget.initialAuthor,
              genre: widget.initialGenre,
              listingType: widget.initialListingType,
              city: widget.initialCity,
              sort: widget.initialSort,
            ));
      });
    } else if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(browseControllerProvider.notifier).updateTitle(widget.initialTitle),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(browseControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(browseControllerProvider.notifier).updateTitle(value.trim().isEmpty ? null : value.trim());
    });
  }

  void _selectPopularSearch(String query) {
    _searchController.text = query;
    ref.read(browseControllerProvider.notifier).updateTitle(query);
  }

  Future<void> _openFilters() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final current = ref.read(browseControllerProvider).filters;
    final result = await showBrowseFiltersSheet(context, current: current);
    _sheetOpen = false;
    if (result != null) {
      ref.read(browseControllerProvider.notifier).applyFilters(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browseControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browseTitle),
        actions: [
          IconButton(
            onPressed: () => context.push('/map'),
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.browseMapTooltip,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: l10n.browseSearchHint,
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _openFilters,
                    icon: Icon(
                      state.filters.hasActiveFilters
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                    ),
                  ),
                ],
              ),
            ),
            if (_searchController.text.trim().isEmpty && !state.filters.hasActiveFilters)
              _PopularSearches(onSelect: _selectPopularSearch),
            Expanded(child: _BrowseResults(state: state, scrollController: _scrollController)),
          ],
        ),
      ),
    );
  }
}

class _PopularSearches extends ConsumerWidget {
  const _PopularSearches({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_popularSearchesProvider);
    return async.when(
      data: (searches) {
        if (searches.isEmpty) return const SizedBox.shrink();
        // Rând orizontal cu scroll, nu `Wrap` - cu destule sugestii populare,
        // un Wrap se întindea pe 3-4 rânduri și ocupa o bucată mare din ecran
        // înainte să apară vreun rezultat.
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: searches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final search = searches[index];
              return ActionChip(
                label: Text(search.query),
                onPressed: () => onSelect(search.query),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _BrowseResults extends ConsumerWidget {
  const _BrowseResults({required this.state, required this.scrollController});
  final BrowseState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const CenteredScrollable(child: CircularProgressIndicator());
    }

    if (state.hasError) {
      return CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.homeLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.read(browseControllerProvider.notifier).retry(),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return CenteredScrollable(child: Text(context.l10n.browseEmpty));
    }

    // GridView responsiv (aceleași metrici ca Home/Wishlist/Raftul meu), nu
    // `Wrap` cu carduri de lățime fixă - pe un telefon îngust, 160+16+160
    // depășea lățimea utilă și tot rândul cădea pe o singură coloană lipită
    // de margine.
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: kBookCardMaxWidth,
              mainAxisSpacing: kBookGridMainAxisSpacing,
              crossAxisSpacing: kBookGridCrossAxisSpacing,
              childAspectRatio: kBookCardAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final userBook = state.items[index];
                return BookCard(
                  userBook: userBook,
                  onTap: () => context.push('/books/${userBook.id}', extra: userBook.owner),
                );
              },
              childCount: state.items.length,
            ),
          ),
        ),
        if (state.isLoadingMore)
          const SliverPadding(
            padding: EdgeInsets.symmetric(vertical: 24),
            sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          ),
      ],
    );
  }
}
