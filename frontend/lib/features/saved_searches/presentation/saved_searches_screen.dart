import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/saved_search.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/city_autocomplete.dart';
import '../application/saved_searches_controller.dart';

/// Feature backlog #6 - alertă la anunțuri noi care se potrivesc unor
/// criterii salvate (gen/oraș/preț maxim), nu unui titlu anume ca la
/// Wishlist. Vezi notifyOnNewListing/notifyOnPriceSet în books.service.ts.
class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final labelController = TextEditingController();
    final genreController = TextEditingController();
    final priceController = TextEditingController();
    String? city;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.savedSearchNew),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    labelText: l10n.savedSearchLabelLabel,
                    hintText: l10n.savedSearchLabelHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: genreController,
                  decoration: InputDecoration(labelText: l10n.filtersGenre),
                ),
                const SizedBox(height: 12),
                CityAutocomplete(
                  value: city,
                  label: l10n.filtersAnyCity,
                  onChanged: (value) => setState(() => city = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.savedSearchMaxPriceLabel),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonSave)),
          ],
        ),
      ),
    );

    labelController.dispose();
    if (created != true) {
      genreController.dispose();
      priceController.dispose();
      return;
    }
    final label = labelController.text.trim();
    final genre = genreController.text.trim();
    final price = double.tryParse(priceController.text.trim().replaceAll(',', '.'));
    genreController.dispose();
    priceController.dispose();
    if (label.isEmpty || !context.mounted) return;

    try {
      await ref.read(savedSearchesControllerProvider.notifier).create(
            label: label,
            genre: genre.isEmpty ? null : genre,
            city: city,
            maxPrice: price,
          );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.savedSearchCreateError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedSearchesControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedSearchesTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateDialog(context, ref),
        tooltip: l10n.savedSearchNew,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: state.when(
          data: (searches) {
            if (searches.isEmpty) {
              return CenteredScrollable(child: Text(l10n.savedSearchesEmpty, textAlign: TextAlign.center));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: searches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _SavedSearchTile(search: searches[index]),
            );
          },
          loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
          error: (error, _) => CenteredScrollable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.savedSearchesLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.read(savedSearchesControllerProvider.notifier).refresh(),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedSearchTile extends ConsumerWidget {
  const _SavedSearchTile({required this.search});
  final SavedSearch search;

  String _formatAmount(double amount) {
    return amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chips = [
      if (search.genre != null) search.genre!,
      if (search.city != null) search.city!,
      if (search.maxPrice != null) l10n.savedSearchMaxPriceChip(_formatAmount(search.maxPrice!)),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(search.label),
        subtitle: chips.isNotEmpty
            ? Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final chip in chips)
                    Chip(
                      label: Text(chip, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.muted,
                    ),
                ],
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.commonDelete,
          onPressed: () => ref.read(savedSearchesControllerProvider.notifier).remove(search.id),
        ),
      ),
    );
  }
}
