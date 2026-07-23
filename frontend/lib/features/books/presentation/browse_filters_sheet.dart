import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/romanian_cities.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/book.dart';
import '../application/browse_controller.dart';
import '../data/books_repository.dart';

/// Deschide un bottom sheet cu filtrele avansate de căutare și întoarce
/// noul set de filtre dacă userul apasă "Aplică", sau null dacă renunță.
Future<BrowseFilters?> showBrowseFiltersSheet(
  BuildContext context, {
  required BrowseFilters current,
}) {
  return showModalBottomSheet<BrowseFilters>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BrowseFiltersSheet(initial: current),
  );
}

class _BrowseFiltersSheet extends ConsumerStatefulWidget {
  const _BrowseFiltersSheet({required this.initial});
  final BrowseFilters initial;

  @override
  ConsumerState<_BrowseFiltersSheet> createState() => _BrowseFiltersSheetState();
}

class _BrowseFiltersSheetState extends ConsumerState<_BrowseFiltersSheet> {
  late final _authorController = TextEditingController(text: widget.initial.author);
  late final _genreController = TextEditingController(text: widget.initial.genre);
  late final _languageController = TextEditingController(text: widget.initial.language);
  late String? _city = widget.initial.city;
  late BookCondition? _condition = widget.initial.condition;
  late int? _maxDistanceKm = widget.initial.maxDistanceKm;

  Timer? _authorDebounce;
  Timer? _genreDebounce;
  Timer? _languageDebounce;
  List<String> _authorSuggestions = const [];
  List<String> _genreSuggestions = const [];
  List<String> _languageSuggestions = const [];

  @override
  void dispose() {
    _authorDebounce?.cancel();
    _genreDebounce?.cancel();
    _languageDebounce?.cancel();
    _authorController.dispose();
    _genreController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  // Auto-fill ca la adăugarea unei cărți (listă de sugestii sub câmp, tap ca
  // să completeze) - dar aici sugestiile vin din cărțile deja listate de alți
  // useri, nu dintr-un API extern, ca userul să nu caute după valori care nu
  // există în catalogul curent.
  void _onAuthorChanged(String value) {
    _authorDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _authorSuggestions = const []);
      return;
    }
    _authorDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await ref.read(booksRepositoryProvider).getAuthorSuggestions(value.trim());
      if (mounted) setState(() => _authorSuggestions = results);
    });
  }

  void _onGenreChanged(String value) {
    _genreDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _genreSuggestions = const []);
      return;
    }
    _genreDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await ref.read(booksRepositoryProvider).getGenres(query: value.trim());
      if (mounted) setState(() => _genreSuggestions = results.map((g) => g.genre).toList());
    });
  }

  void _onLanguageChanged(String value) {
    _languageDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _languageSuggestions = const []);
      return;
    }
    _languageDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await ref.read(booksRepositoryProvider).getLanguageSuggestions(value.trim());
      if (mounted) setState(() => _languageSuggestions = results);
    });
  }

  Widget _suggestions(List<String> options, TextEditingController controller, VoidCallback onPicked) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ActionChip(
              label: Text(option),
              onPressed: () {
                controller.text = option;
                onPicked();
              },
            ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _authorController.clear();
      _genreController.clear();
      _languageController.clear();
      _city = null;
      _condition = null;
      _maxDistanceKm = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      BrowseFilters(
        title: widget.initial.title,
        author: _authorController.text.trim().isEmpty ? null : _authorController.text.trim(),
        genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
        city: _city,
        condition: _condition,
        maxDistanceKm: _maxDistanceKm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.filtersTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _authorController,
              onChanged: _onAuthorChanged,
              decoration: InputDecoration(labelText: l10n.filtersAuthor),
            ),
            _suggestions(
              _authorSuggestions,
              _authorController,
              () => setState(() => _authorSuggestions = const []),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _genreController,
              onChanged: _onGenreChanged,
              decoration: InputDecoration(labelText: l10n.filtersGenre),
            ),
            _suggestions(
              _genreSuggestions,
              _genreController,
              () => setState(() => _genreSuggestions = const []),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _languageController,
              onChanged: _onLanguageChanged,
              decoration: InputDecoration(labelText: l10n.filtersLanguage),
            ),
            _suggestions(
              _languageSuggestions,
              _languageController,
              () => setState(() => _languageSuggestions = const []),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _city,
              decoration: InputDecoration(labelText: l10n.profileCityLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.filtersAnyCity)),
                for (final city in kRomanianCities)
                  DropdownMenuItem(value: city, child: Text(city)),
              ],
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BookCondition?>(
              initialValue: _condition,
              decoration: InputDecoration(labelText: l10n.filtersCondition),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.filtersAnyCondition)),
                for (final condition in BookCondition.values)
                  DropdownMenuItem(value: condition, child: Text(condition.label)),
              ],
              onChanged: (value) => setState(() => _condition = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.filtersNearbyOnly),
              subtitle: Text(
                _maxDistanceKm == null
                    ? l10n.filtersNearbyOnlyHintOff
                    : l10n.filtersNearbyOnlyHintOn(_maxDistanceKm!),
              ),
              value: _maxDistanceKm != null,
              onChanged: (value) => setState(() => _maxDistanceKm = value ? 100 : null),
            ),
            if (_maxDistanceKm != null)
              Slider(
                value: _maxDistanceKm!.toDouble(),
                min: 10,
                max: 500,
                divisions: 49,
                label: l10n.filtersDistanceKm(_maxDistanceKm!),
                onChanged: (value) => setState(() => _maxDistanceKm = value.round()),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: Text(l10n.filtersReset),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: Text(l10n.filtersApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
