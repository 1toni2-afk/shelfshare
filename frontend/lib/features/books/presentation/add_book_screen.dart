import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/romanian_cities.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/external_book_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/my_library_controller.dart';
import '../data/auctions_repository.dart';
import '../data/books_repository.dart';

/// Ecranul „+ Share" refăcut pe layout-ul din Milestone 10:
///
/// 1. Sus: câmp „+" pentru poze (până în 5).
/// 2. Titlul cărții cu autocomplete după căutare externă (Google/OpenLibrary);
///    tap pe o sugestie completează autor/gen/an, dar toate rămân editabile.
/// 3. Autor (auto-populat, editabil).
/// 4. Gen + taguri (până în 5).
/// 5. Descriere per exemplar (max 256 caractere).
/// 6. Mod de anunț: schimb / vânzare / licitație / donație (single-select).
/// 7. Localitate (unde se face schimbul).
/// 8. Buton „Mai multe informații" care extinde pagini/an/editura.
class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

enum _ListingMode { swap, sale, auction, donation }

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _genreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _priceController = TextEditingController();
  final _reservePriceController = TextEditingController();
  final _buyNowPriceController = TextEditingController();
  final _pageCountController = TextEditingController();
  final _publishedYearController = TextEditingController();
  final _editionYearController = TextEditingController();
  final _publisherController = TextEditingController();

  final List<String> _tags = [];
  final List<XFile> _photos = [];

  bool _isSubmitting = false;
  bool _showMoreInfo = false;
  BookCondition _condition = BookCondition.buna;
  bool _isHardcover = false;
  _ListingMode _listingMode = _ListingMode.swap;
  int _auctionDurationHours = 24;
  bool _isNegotiable = true;
  String? _city;
  String? _isbnFromAutocomplete;

  Timer? _searchDebounce;

  static const _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() => setState(() {}));
    // Preselect city din profil, dacă există - user o poate schimba.
    final auth = ref.read(authControllerProvider);
    if (auth is AuthAuthenticated) {
      _city = auth.user.city;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _titleController.dispose();
    _authorController.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    _priceController.dispose();
    _reservePriceController.dispose();
    _buyNowPriceController.dispose();
    _pageCountController.dispose();
    _publishedYearController.dispose();
    _editionYearController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(remaining)));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _addTag(String raw) {
    final l10n = context.l10n;
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (_tags.length >= 5) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shareMaxTagsReached)));
      return;
    }
    if (_tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  Future<Iterable<ExternalBookResult>> _titleAutocomplete(String query) async {
    if (query.trim().length < 2) return const [];
    // Debouncing simplu la nivel de tastare: dacă altă cerere e programată,
    // o anulăm - nu vrem 10 request-uri pentru „Harry Potter".
    _searchDebounce?.cancel();
    final completer = Completer<Iterable<ExternalBookResult>>();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results =
            await ref.read(booksRepositoryProvider).searchExternal(query.trim());
        completer.complete(results);
      } catch (_) {
        completer.complete(const []);
      }
    });
    return completer.future;
  }

  void _applySuggestion(ExternalBookResult result) {
    setState(() {
      _titleController.text = result.title;
      if (result.author != null) _authorController.text = result.author!;
      if (result.genre != null && _genreController.text.isEmpty) {
        _genreController.text = result.genre!;
      }
      if (result.pageCount != null && _pageCountController.text.isEmpty) {
        _pageCountController.text = result.pageCount!.toString();
      }
      if (result.publishedYear != null && _publishedYearController.text.isEmpty) {
        _publishedYearController.text = result.publishedYear!.toString();
      }
      if (result.publisher != null && _publisherController.text.isEmpty) {
        _publisherController.text = result.publisher!;
      }
      _isbnFromAutocomplete = result.isbn;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addBookTitleRequired)));
      return;
    }
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addBookNeedPhoto)),
      );
      return;
    }
    final wantsPrice = _listingMode == _ListingMode.sale ||
        _listingMode == _ListingMode.auction;
    final salePrice = wantsPrice
        ? double.tryParse(_priceController.text.trim().replaceAll(',', '.'))
        : null;
    if (wantsPrice && salePrice == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addBookInvalidPrice)));
      return;
    }
    final reservePrice = _reservePriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_reservePriceController.text.trim().replaceAll(',', '.'));
    final buyNowPrice = _buyNowPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_buyNowPriceController.text.trim().replaceAll(',', '.'));

    setState(() => _isSubmitting = true);
    try {
      final userBook = await ref.read(booksRepositoryProvider).addToLibrary(
            isbn: _isbnFromAutocomplete,
            title: title,
            author: _authorController.text.trim().isEmpty
                ? null
                : _authorController.text.trim(),
            condition: _condition,
            isHardcover: _isHardcover,
            genre: _genreController.text.trim().isEmpty
                ? null
                : _genreController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            tags: _tags.isEmpty ? null : _tags,
            city: _city,
            publisher: _publisherController.text.trim().isEmpty
                ? null
                : _publisherController.text.trim(),
            publishedYear: int.tryParse(_publishedYearController.text.trim()),
            editionYear: int.tryParse(_editionYearController.text.trim()),
            pageCount: int.tryParse(_pageCountController.text.trim()),
          );
      for (final photo in _photos) {
        await ref.read(booksRepositoryProvider).addPhoto(
              userBook.id,
              bytes: await photo.readAsBytes(),
              filename: photo.name,
            );
      }
      if (_listingMode == _ListingMode.sale) {
        await ref.read(booksRepositoryProvider).markForSale(
              userBook.id,
              salePrice: salePrice!,
              isNegotiable: _isNegotiable,
            );
      } else if (_listingMode == _ListingMode.auction) {
        await ref.read(auctionsRepositoryProvider).createAuction(
              userBook.id,
              startingPrice: salePrice!,
              reservePrice: reservePrice,
              buyNowPrice: buyNowPrice,
              durationHours: _auctionDurationHours,
            );
      } else if (_listingMode == _ListingMode.donation) {
        // „Donație" = anunț ne-negociabil la preț 0. Nu avem coloană separată
        // în DB - modelul de preț acoperă cazul cu 0 lei + non-negotiable.
        await ref.read(booksRepositoryProvider).markForSale(
              userBook.id,
              salePrice: 0,
              isNegotiable: false,
            );
      }
      ref.invalidate(myLibraryControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.addBookSuccess)));
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
    final charsLeft = 256 - _descriptionController.text.length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addBookTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Poze - sus, cu placeholder mare cu „+"
            _PhotoPicker(
              photos: _photos,
              maxPhotos: _maxPhotos,
              onPick: _pickPhotos,
              onRemove: _removePhoto,
            ),
            const SizedBox(height: 24),

            // 2. Titlu cu autocomplete
            Autocomplete<ExternalBookResult>(
              displayStringForOption: (r) => r.title,
              optionsBuilder: (value) => _titleAutocomplete(value.text),
              onSelected: _applySuggestion,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                // Sincronizăm cu propriul controller pentru a putea prelua
                // textul la submit chiar dacă userul nu a ales o sugestie.
                controller.text = _titleController.text;
                controller.addListener(() {
                  if (_titleController.text != controller.text) {
                    _titleController.text = controller.text;
                  }
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: l10n.shareTitleHint,
                    helperText: l10n.shareTitleAutocomplete,
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(option.title, maxLines: 1),
                            subtitle: option.author != null
                                ? Text(option.author!, maxLines: 1)
                                : null,
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 3. Autor
            TextField(
              controller: _authorController,
              decoration: InputDecoration(labelText: l10n.shareAuthorHint),
            ),
            const SizedBox(height: 12),

            // 4. Gen + taguri
            TextField(
              controller: _genreController,
              decoration: InputDecoration(labelText: l10n.shareGenreHint),
            ),
            const SizedBox(height: 12),
            _TagsInput(
              tags: _tags,
              controller: _tagInputController,
              hint: l10n.shareTagsHint,
              onAdd: _addTag,
              onRemove: _removeTag,
            ),
            const SizedBox(height: 20),

            // 5. Descriere
            TextField(
              controller: _descriptionController,
              maxLength: 256,
              maxLines: 4,
              inputFormatters: [LengthLimitingTextInputFormatter(256)],
              decoration: InputDecoration(
                labelText: l10n.shareDescriptionHint,
                counterText: l10n.shareDescriptionCharsLeft(charsLeft),
              ),
            ),
            const SizedBox(height: 20),

            // 6. Mod de listare
            Text(l10n.shareListingMode,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _ListingModePicker(
              mode: _listingMode,
              onChanged: (m) => setState(() => _listingMode = m),
            ),
            if (_listingMode == _ListingMode.sale ||
                _listingMode == _ListingMode.auction) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _listingMode == _ListingMode.auction
                      ? l10n.addBookAuctionStartingPrice
                      : l10n.addBookPriceLabel,
                  suffixText: 'lei',
                ),
              ),
              if (_listingMode == _ListingMode.sale) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  // Switch pornit = preț fix (`_isNegotiable = false`); pornit
                  // vizual e „nenegociabil ON" - stat logic inversat.
                  title: Text(l10n.addBookNonNegotiable),
                  value: !_isNegotiable,
                  onChanged: (v) => setState(() => _isNegotiable = !v),
                ),
              ],
              if (_listingMode == _ListingMode.auction) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _reservePriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.addBookAuctionReservePrice,
                    suffixText: 'lei',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _buyNowPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.addBookAuctionBuyNowPrice,
                    suffixText: 'lei',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _auctionDurationHours,
                  decoration: InputDecoration(
                      labelText: l10n.addBookAuctionDuration),
                  items: const [24, 48, 72, 168]
                      .map((h) => DropdownMenuItem(
                          value: h, child: Text('$h h')))
                      .toList(),
                  onChanged: (v) => setState(
                      () => _auctionDurationHours = v ?? 24),
                ),
              ],
            ],
            const SizedBox(height: 20),

            // 7. Localitate
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: InputDecoration(labelText: l10n.shareCityHint),
              items: [
                for (final c in kRomanianCities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: 12),

            // Stare (obligatoriu, dar nu în lista explicită a userului -
            // păstrat pentru că backend-ul îl cere).
            DropdownButtonFormField<BookCondition>(
              initialValue: _condition,
              decoration:
                  InputDecoration(labelText: l10n.filtersCondition),
              items: [
                for (final c in BookCondition.values)
                  DropdownMenuItem(value: c, child: Text(c.label(l10n))),
              ],
              onChanged: (v) => setState(() => _condition = v ?? _condition),
            ),

            const SizedBox(height: 20),

            // 8. „Mai multe informații" - collapsible
            InkWell(
              onTap: () => setState(() => _showMoreInfo = !_showMoreInfo),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(l10n.shareMoreInfo,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 4),
                    Icon(_showMoreInfo
                        ? Icons.expand_less
                        : Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (_showMoreInfo) ...[
              TextField(
                controller: _pageCountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                    labelText: l10n.sharePageCountCustom),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _publishedYearController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                    labelText: l10n.sharePublishedYear),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _editionYearController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration:
                    InputDecoration(labelText: l10n.shareEditionYear),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _publisherController,
                decoration: InputDecoration(labelText: l10n.sharePublisher),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.addBookHardcoverSwitch),
                value: _isHardcover,
                onChanged: (v) => setState(() => _isHardcover = v),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.shareSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder mare cu „+" + thumbnails cu poze urcate + „X" de ștergere.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.maxPhotos,
    required this.onPick,
    required this.onRemove,
  });
  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onPick;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: photos.length >= maxPhotos ? null : onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined,
                    size: 42, color: AppColors.mutedForeground),
                const SizedBox(height: 6),
                Text(
                  context.l10n.shareAddPhotos,
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
                Text(
                  '${photos.length} / $maxPhotos',
                  style: TextStyle(
                      color: AppColors.mutedForeground, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<Uint8List>(
                        future: photo.readAsBytes(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return Container(
                                width: 80,
                                height: 80,
                                color: AppColors.muted);
                          }
                          return Image.memory(
                            snap.data!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => onRemove(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.destructive,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Câmp text + chip-uri; enter/virgulă adaugă tag-ul curent.
class _TagsInput extends StatelessWidget {
  const _TagsInput({
    required this.tags,
    required this.controller,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> tags;
  final TextEditingController controller;
  final String hint;
  final void Function(String) onAdd;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: hint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onAdd(controller.text),
            ),
          ),
          onSubmitted: onAdd,
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tags)
                Chip(
                  label: Text(t),
                  onDeleted: () => onRemove(t),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ListingModePicker extends StatelessWidget {
  const _ListingModePicker({required this.mode, required this.onChanged});
  final _ListingMode mode;
  final void Function(_ListingMode) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(_ListingMode, String, IconData)>[
      (_ListingMode.swap, l10n.shareListingModeSwap, Icons.swap_horiz),
      (_ListingMode.sale, l10n.shareListingModeSale, Icons.sell_outlined),
      (_ListingMode.auction, l10n.shareListingModeAuction, Icons.gavel_outlined),
      (_ListingMode.donation, l10n.shareListingModeDonation, Icons.volunteer_activism_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (m, label, icon) in options)
          ChoiceChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            selected: mode == m,
            onSelected: (_) => onChanged(m),
          ),
      ],
    );
  }
}
