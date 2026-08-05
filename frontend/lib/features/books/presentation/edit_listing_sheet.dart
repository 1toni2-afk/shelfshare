import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/city_autocomplete.dart';
import '../application/my_library_controller.dart';

/// Editarea completă a unui anunț propriu (Milestone 18: „toate câmpurile").
/// Extras din my_library_screen ca să poată fi deschis și din pagina anunțului
/// (book_detail), nu doar din foaia de acțiuni a bibliotecii.
///
/// Deschide-l cu `showModalBottomSheet(isScrollControlled: true, ...)`. Se
/// închide singur la salvare reușită.
class EditListingSheet extends ConsumerStatefulWidget {
  const EditListingSheet({super.key, required this.userBook});
  final UserBook userBook;

  @override
  ConsumerState<EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends ConsumerState<EditListingSheet> {
  late BookCondition _condition = widget.userBook.condition;
  late final _languageController =
      TextEditingController(text: widget.userBook.language);
  late final _editionController =
      TextEditingController(text: widget.userBook.edition);
  late bool _isHardcover = widget.userBook.isHardcover;
  late bool _availableForSwap = widget.userBook.availableForSwap;
  late bool _isForSale = widget.userBook.isForSale;
  late bool _isNegotiable = widget.userBook.isNegotiable;
  late final _priceController = TextEditingController(
    text: widget.userBook.salePrice?.toStringAsFixed(0) ?? '',
  );
  late final _descriptionController =
      TextEditingController(text: widget.userBook.description);
  late String? _city = widget.userBook.city;
  // Tag-urile se editează ca text separat prin virgulă - simplu și suficient
  // pentru maxim 5 etichete. La salvare le despărțim, curățăm și limităm.
  late final _tagsController =
      TextEditingController(text: widget.userBook.tags.join(', '));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _languageController.dispose();
    _editionController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    final seen = <String>{};
    final tags = <String>[];
    for (final raw in _tagsController.text.split(',')) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      // Dedupe case-insensitive, păstrând forma tastată prima dată.
      if (seen.add(tag.toLowerCase())) tags.add(tag);
      if (tags.length >= 5) break;
    }
    return tags;
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final salePrice =
        double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    if (_isForSale && salePrice == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addBookInvalidPrice)));
      return;
    }
    if (_isForSale && widget.userBook.photos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addBookNeedPhoto)));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(myLibraryControllerProvider.notifier).editListing(
            widget.userBook.id,
            condition: _condition,
            language: _trimmedOrNull(_languageController.text),
            edition: _trimmedOrNull(_editionController.text),
            isHardcover: _isHardcover,
            availableForSwap: _availableForSwap,
            isForSale: _isForSale,
            salePrice: _isForSale ? salePrice : null,
            isNegotiable: _isNegotiable,
            description: _trimmedOrNull(_descriptionController.text),
            tags: _parseTags(),
            city: _city,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.libraryEditListingSuccess)));
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List
                ? (data['message'] as List).join(', ')
                : data['message'].toString())
            : l10n.addBookGenericError;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
            Text(l10n.libraryEditListingTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            DropdownButtonFormField<BookCondition>(
              initialValue: _condition,
              decoration: InputDecoration(labelText: l10n.filtersCondition),
              items: [
                for (final condition in BookCondition.values)
                  DropdownMenuItem(
                      value: condition, child: Text(condition.label(l10n))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _condition = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _languageController,
              decoration:
                  InputDecoration(labelText: l10n.addBookLanguageOptional),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _editionController,
              decoration:
                  InputDecoration(labelText: l10n.addBookEditionOptional),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLength: 256,
              maxLines: 3,
              decoration:
                  InputDecoration(labelText: l10n.shareDescriptionHint),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(labelText: l10n.shareTagsHint),
            ),
            const SizedBox(height: 16),
            CityAutocomplete(
              value: _city,
              label: l10n.shareCityHint,
              emptyLabel: l10n.shareCityUnknown,
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.libraryAvailableForSwap),
              value: _availableForSwap,
              onChanged: (value) => setState(() => _availableForSwap = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addBookHardcoverSwitch),
              value: _isHardcover,
              onChanged: (value) => setState(() => _isHardcover = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addBookForSaleSwitch),
              subtitle: Text(l10n.addBookForSaleHint),
              value: _isForSale,
              onChanged: (value) => setState(() => _isForSale = value),
            ),
            if (_isForSale) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: l10n.addBookPriceLabel, suffixText: 'lei'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.addBookNonNegotiable),
                subtitle: Text(l10n.addBookNonNegotiableHint),
                value: !_isNegotiable,
                onChanged: (value) => setState(() => _isNegotiable = !value),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _save,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
