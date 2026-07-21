import 'package:flutter/material.dart';
import '../../../core/constants/romanian_cities.dart';
import '../../../data/models/book.dart';
import '../application/browse_controller.dart';

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

class _BrowseFiltersSheet extends StatefulWidget {
  const _BrowseFiltersSheet({required this.initial});
  final BrowseFilters initial;

  @override
  State<_BrowseFiltersSheet> createState() => _BrowseFiltersSheetState();
}

class _BrowseFiltersSheetState extends State<_BrowseFiltersSheet> {
  late final _authorController = TextEditingController(text: widget.initial.author);
  late final _genreController = TextEditingController(text: widget.initial.genre);
  late final _languageController = TextEditingController(text: widget.initial.language);
  late String? _city = widget.initial.city;
  late BookCondition? _condition = widget.initial.condition;
  late int? _maxDistanceKm = widget.initial.maxDistanceKm;

  @override
  void dispose() {
    _authorController.dispose();
    _genreController.dispose();
    _languageController.dispose();
    super.dispose();
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
            Text('Filtre', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Autor'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _genreController,
              decoration: const InputDecoration(labelText: 'Gen'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _languageController,
              decoration: const InputDecoration(labelText: 'Limbă'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'Oraș'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Orice oraș')),
                for (final city in kRomanianCities)
                  DropdownMenuItem(value: city, child: Text(city)),
              ],
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BookCondition?>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Stare'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Orice stare')),
                for (final condition in BookCondition.values)
                  DropdownMenuItem(value: condition, child: Text(condition.label)),
              ],
              onChanged: (value) => setState(() => _condition = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Doar din apropiere'),
              subtitle: Text(
                _maxDistanceKm == null
                    ? 'Ordonează și filtrează după distanța reală față de orașul tău'
                    : 'Până la $_maxDistanceKm km de orașul tău',
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
                label: '$_maxDistanceKm km',
                onChanged: (value) => setState(() => _maxDistanceKm = value.round()),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Resetează'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text('Aplică filtre'),
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
