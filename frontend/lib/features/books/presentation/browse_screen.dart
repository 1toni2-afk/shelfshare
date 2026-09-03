import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/external_book_result.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_grid_metrics.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/browse_controller.dart';
import '../data/books_repository.dart';
import 'browse_filters_sheet.dart';

final _popularSearchesProvider = FutureProvider((ref) {
  return ref.watch(booksRepositoryProvider).getPopularSearches();
});

/// Cautarea "peste tot": catalogul propriu + Google Books / Open Library.
/// `autoDispose`, ca rezultatele sa nu se adune in memorie pentru fiecare
/// termen tastat intr-o sesiune de cautare.
final globalBookSearchProvider = FutureProvider.autoDispose
    .family<List<ExternalBookResult>, String>((ref, query) {
  return ref.watch(booksRepositoryProvider).searchExternal(query);
});


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
                      textAlignVertical: TextAlignVertical.center,
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
            Expanded(
              child: _BrowseResults(
                state: state,
                scrollController: _scrollController,
                // Cautarea globala porneste de la ce e efectiv aplicat ca
                // filtru, nu de la textul din camp: altfel ar cere rezultate
                // externe la fiecare tasta, inaintea debounce-ului.
                globalQuery: state.filters.title,
              ),
            ),
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
  const _BrowseResults({
    required this.state,
    required this.scrollController,
    required this.globalQuery,
  });

  final BrowseState state;
  final ScrollController scrollController;

  /// Termenul pentru care cautam si in afara anunturilor din aplicatie.
  final String? globalQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = globalQuery?.trim();
    final hasQuery = query != null && query.length >= 2;

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

    // Fara niciun anunt SI fara termen de cautare nu avem ce arata - starea
    // goala ramane cea de dinainte. Cu termen, mesajul "niciun rezultat" e
    // doar despre anunturi: sectiunea globala de dedesubt e exact motivul
    // pentru care ecranul nu se mai opreste aici.
    if (state.items.isEmpty && !hasQuery) {
      return CenteredScrollable(child: Text(context.l10n.browseEmpty));
    }

    // GridView responsiv (aceleași metrici ca Home/Wishlist/Raftul meu), nu
    // `Wrap` cu carduri de lățime fixă - pe un telefon îngust, 160+16+160
    // depășea lățimea utilă și tot rândul cădea pe o singură coloană lipită
    // de margine.
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (state.items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(context.l10n.browseEmpty, textAlign: TextAlign.center),
            ),
          )
        else
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
        if (hasQuery)
          SliverToBoxAdapter(child: _GlobalResultsSection(query: query)),
      ],
    );
  }
}

/// „Toate cărțile": rezultate din catalogul propriu ȘI de la Google Books /
/// Open Library, nu doar din anunțurile active.
///
/// Motivul pentru care există: până acum, o carte pe care n-o listase nimeni
/// pur și simplu nu exista din perspectiva căutării - userul primea „niciun
/// rezultat" pentru un titlu perfect real. Acum primește cartea, cu pagina ei,
/// de unde o poate pune pe raft sau o poate lista el însuși.
class _GlobalResultsSection extends ConsumerWidget {
  const _GlobalResultsSection({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(globalBookSearchProvider(query));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          Text(l10n.browseGlobalTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.browseGlobalSubtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            // Sursele externe pică des (cotă depășită, timeout), iar căutarea
            // în anunțuri de deasupra rămâne utilă - deci eroarea ia doar
            // secțiunea asta, nu ecranul.
            error: (_, _) =>
                _AddTitleCta(query: query, label: l10n.browseGlobalError),
            data: (results) {
              if (results.isEmpty) {
                return _AddTitleCta(
                  query: query,
                  label: l10n.browseGlobalEmpty(query),
                );
              }
              return Column(
                children: [
                  for (final result in results) _GlobalResultTile(result: result),
                  const SizedBox(height: 8),
                  _AddTitleCta(query: query, label: l10n.browseGlobalNotFound),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlobalResultTile extends ConsumerStatefulWidget {
  const _GlobalResultTile({required this.result});
  final ExternalBookResult result;

  @override
  ConsumerState<_GlobalResultTile> createState() => _GlobalResultTileState();
}

class _GlobalResultTileState extends ConsumerState<_GlobalResultTile> {
  bool _opening = false;

  /// Rezultatele din catalogul propriu au deja `bookId`; cele externe îl
  /// primesc acum, la deschidere - serverul le caută întâi după ISBN, apoi
  /// după titlu+autor, și abia dacă nu le găsește creează ceva (vezi
  /// BooksService.resolveWork), deci deschiderea repetată nu umple catalogul.
  Future<void> _open() async {
    final existing = widget.result.bookId;
    if (existing != null) {
      context.push('/work/$existing');
      return;
    }
    setState(() => _opening = true);
    try {
      final bookId =
          await ref.read(booksRepositoryProvider).resolveWork(widget.result);
      if (mounted) context.push('/work/$bookId');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonGenericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final meta = [
      if (result.publishedYear != null) '${result.publishedYear}',
      if (result.publisher != null && result.publisher!.trim().isNotEmpty)
        result.publisher!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _opening ? null : _open,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              BookCover(
                url: result.coverUrl,
                title: result.title,
                width: 40,
                height: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.author != null)
                      Text(
                        result.author!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                  ],
                ),
              ),
              if (_opening)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ieșirea din fundătură: titlul nu e nici la noi, nici la sursele externe -
/// atunci userul îl adaugă el, cu o poză proprie drept copertă (ecranul de
/// adăugare are deja selectorul de poze).
class _AddTitleCta extends StatelessWidget {
  const _AddTitleCta({required this.query, required this.label});
  final String query;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push(
              // `mode=listing`, nu raftul personal: modul de listare e singurul
              // cu selector de poze, iar promisiunea de aici e exact „adaugă
              // titlul cu poza ta drept copertă".
              Uri(
                path: '/library/add',
                queryParameters: {'mode': 'listing', 'title': query},
              ).toString(),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(context.l10n.browseAddTitleCta),
          ),
        ),
      ],
    );
  }
}
