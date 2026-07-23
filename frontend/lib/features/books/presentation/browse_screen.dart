import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/browse_controller.dart';
import 'browse_filters_sheet.dart';

/// Argumente opționale trimise ecranului de căutare din alte ecrane (ex.
/// wishlist trimite un titlu, Home trimite un gen din secțiunea Categorii).
class SearchScreenArgs {
  const SearchScreenArgs({this.title, this.genre});
  final String? title;
  final String? genre;
}

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, this.initialTitle, this.initialGenre});
  final String? initialTitle;
  final String? initialGenre;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  late final _searchController = TextEditingController(text: widget.initialTitle);
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(browseControllerProvider.notifier).updateTitle(widget.initialTitle),
      );
    } else if (widget.initialGenre != null && widget.initialGenre!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(browseControllerProvider.notifier).applyFilters(
              BrowseFilters(genre: widget.initialGenre),
            ),
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
            Expanded(child: _BrowseResults(state: state, scrollController: _scrollController)),
          ],
        ),
      ),
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

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 20,
          children: [
            for (final userBook in state.items)
              BookCard(
                userBook: userBook,
                width: 160,
                onTap: () => context.push('/books/${userBook.id}', extra: userBook.owner),
              ),
          ],
        ),
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
