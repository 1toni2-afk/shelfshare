import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../data/books_repository.dart';
import '../../../data/models/search_screen_args.dart';

/// Genurile disponibile în catalog - aceeași sursă ca autocomplete-ul din
/// filtrele de browse (`/books/genres`), ca să nu inventăm o taxonomie
/// paralelă. Aplicația nu are „categorii" separate de genuri: `Book.genre` e
/// singura taxonomie de conținut, deci „Categorie" din sheet-ul de filtrare o
/// folosește pe aceasta.
final discoverGenresProvider = FutureProvider(
  (ref) => ref.watch(booksRepositoryProvider).getGenres(),
);

/// Tipurile de anunț, exact cele patru din ecranul de adăugare a cărții
/// (vezi `_ListingMode` din add_book_screen.dart). „donation" e o vânzare la
/// preț 0, dar backendul o tratează ca filtru distinct.
const _listingTypes = ['swap', 'sale', 'auction', 'donation'];

String _listingTypeLabel(BuildContext context, String type) {
  final l10n = context.l10n;
  return switch (type) {
    'swap' => l10n.shareListingModeSwap,
    'sale' => l10n.shareListingModeSale,
    'auction' => l10n.shareListingModeAuction,
    _ => l10n.shareListingModeDonation,
  };
}

/// Bottom sheet „Filtrează": categorie (gen) + tip de anunț. Rezultatul e
/// aplicat pe ecranul de căutare (`/browse`), care e singurul loc cu paginare
/// și filtre reale - Discover rămâne un feed de secțiuni curate.
Future<SearchScreenArgs?> showDiscoverFilterSheet(
  BuildContext context, {
  String? genre,
  String? listingType,
}) {
  return showModalBottomSheet<SearchScreenArgs>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _DiscoverFilterSheet(genre: genre, listingType: listingType),
  );
}

/// Bottom sheet „Sortează": gen prioritar + ordinea după dată (crescător /
/// descrescător) + „cele mai apropiate întâi" (fostul filtru rapid de
/// proximitate din bara de chip-uri, ca să nu pierdem capabilitatea).
Future<SearchScreenArgs?> showDiscoverSortSheet(
  BuildContext context, {
  String? genre,
  String? sort,
}) {
  return showModalBottomSheet<SearchScreenArgs>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DiscoverSortSheet(genre: genre, sort: sort),
  );
}

/// Antet comun de sheet: titlu + buton de închidere, ca ambele să arate la fel.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.children, required this.onApply});
  final String title;
  final List<Widget> children;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              ...children,
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onApply,
                  child: Text(context.l10n.filtersApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Grup de chip-uri cu o singură selecție, cu opțiunea „Toate" (= fără filtru)
/// mereu prima. Folosit și pentru genuri și pentru tipul de anunț.
class _SingleChoiceChips extends StatelessWidget {
  const _SingleChoiceChips({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String Function(String) labelOf;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(context.l10n.discoverFilterAll),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final option in options)
          ChoiceChip(
            label: Text(labelOf(option)),
            selected: selected == option,
            onSelected: (_) => onChanged(option),
          ),
      ],
    );
  }
}

class _DiscoverFilterSheet extends ConsumerStatefulWidget {
  const _DiscoverFilterSheet({this.genre, this.listingType});
  final String? genre;
  final String? listingType;

  @override
  ConsumerState<_DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends ConsumerState<_DiscoverFilterSheet> {
  late String? _genre = widget.genre;
  late String? _listingType = widget.listingType;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final genres = ref.watch(discoverGenresProvider).value ?? const [];

    return _SheetScaffold(
      title: l10n.filtersTitle,
      onApply: () => Navigator.of(context).pop(
        SearchScreenArgs(genre: _genre, listingType: _listingType),
      ),
      children: [
        _SectionLabel(l10n.discoverFilterCategory),
        _SingleChoiceChips(
          options: genres.map((g) => g.genre).toList(),
          labelOf: (value) => value,
          selected: _genre,
          onChanged: (value) => setState(() => _genre = value),
        ),
        _SectionLabel(l10n.discoverFilterListingType),
        _SingleChoiceChips(
          options: _listingTypes,
          labelOf: (value) => _listingTypeLabel(context, value),
          selected: _listingType,
          onChanged: (value) => setState(() => _listingType = value),
        ),
      ],
    );
  }
}

class _DiscoverSortSheet extends ConsumerStatefulWidget {
  const _DiscoverSortSheet({this.genre, this.sort});
  final String? genre;
  final String? sort;

  @override
  ConsumerState<_DiscoverSortSheet> createState() => _DiscoverSortSheetState();
}

class _DiscoverSortSheetState extends ConsumerState<_DiscoverSortSheet> {
  late String? _genre = widget.genre;
  // 'popularity' (implicit) / 'recent' / 'oldest' / 'distance'. Proximitatea
  // nu e o ordine după dată, dar tot o sortare e - o ținem în aceeași
  // variabilă ca să nu poată fi selectate două ordini contradictorii simultan.
  late String _sort = widget.sort ?? 'popularity';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final genres = ref.watch(discoverGenresProvider).value ?? const [];

    return _SheetScaffold(
      title: l10n.discoverSortTitle,
      onApply: () => Navigator.of(context).pop(
        SearchScreenArgs(genre: _genre, sort: _sort),
      ),
      children: [
        _SectionLabel(l10n.discoverSortGenre),
        _SingleChoiceChips(
          options: genres.map((g) => g.genre).toList(),
          labelOf: (value) => value,
          selected: _genre,
          onChanged: (value) => setState(() => _genre = value),
        ),
        _SectionLabel(l10n.discoverSortDate),
        RadioGroup<String>(
          groupValue: _sort,
          onChanged: (value) => setState(() => _sort = value ?? 'popularity'),
          child: Column(
            children: [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'popularity',
                title: Text(l10n.discoverSortPopular),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'recent',
                title: Text(l10n.discoverSortNewest),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'oldest',
                title: Text(l10n.discoverSortOldest),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'distance',
                title: Text(l10n.discoverSortNearest),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
