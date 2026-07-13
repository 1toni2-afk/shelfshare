import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/browse_controller.dart';
import 'browse_filters_sheet.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, this.initialTitle});
  final String? initialTitle;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Caută cărți')),
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
                      decoration: const InputDecoration(
                        hintText: 'Caută după titlu',
                        prefixIcon: Icon(Icons.search),
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

    if (state.error != null) {
      return CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.read(browseControllerProvider.notifier).retry(),
              child: const Text('Încearcă din nou'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return const CenteredScrollable(child: Text('Nicio carte găsită.'));
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
