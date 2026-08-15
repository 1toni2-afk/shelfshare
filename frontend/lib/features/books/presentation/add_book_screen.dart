import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/widgets/city_autocomplete.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/external_book_result.dart';
import '../../../data/models/user_book.dart';
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

  // ---------- Batch 8: cover recomandat + poză principală ----------
  /// URL-ul coperții alese: fie coperta oficială din rezultatul de
  /// autocomplete, fie una dintre cele „recomandate". Se trimite ca
  /// `mainPhotoUrl` la creare - pozele urcate ulterior pot suprascrie
  /// alegerea prin selectorul de mai jos.
  String? _selectedCoverUrl;

  /// Cele 3-4 coperte candidate pentru titlul+autorul curent, când user nu
  /// a ales din autocomplete. Refetch cu debounce la fiecare modificare.
  List<String> _recommendedCovers = const [];
  Timer? _coverSearchDebounce;

  /// Indexul pozei urcate marcate ca „principală" (0-based). Null = nu am
  /// bifat manual nicio poză; UI-ul folosește atunci coperta selectată sau
  /// pica pe fallbackul din UserBook.primaryImageUrl.
  int? _mainPhotoIndex;

  static const _maxPhotos = 5;

  // ---------- Fix duplicat la retry după submit eșuat ----------
  /// Setat imediat după ce `addToLibrary` reușește. Dacă un pas ULTERIOR
  /// (poze, preț/licitație) eșuează (ex. „price must be under 99999") și
  /// userul apasă din nou Trimite fără să corecteze nimic vizibil legat de
  /// carte, `_submit()` NU mai creează o a doua listare de la zero - reia
  /// exact de unde a rămas, pe același UserBook deja creat.
  UserBook? _createdUserBook;
  final List<String?> _uploadedPhotoUrls = [];
  bool _coverUrlAddedToGallery = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() => setState(() {}));
    // Când user modifică manual titlul/autorul (și nu a ales din
    // autocomplete), refetch la coperte după 500ms - vezi Batch 8.
    _titleController.addListener(_scheduleCoverSearch);
    _authorController.addListener(_scheduleCoverSearch);
    // Preselect city din profil, dacă există - user o poate schimba.
    final auth = ref.read(authControllerProvider);
    if (auth is AuthAuthenticated) {
      _city = auth.user.city;
    }
  }

  /// Programăm o interogare la /books/covers cu 500ms debounce. Nu apelăm
  /// dacă user tocmai a ales din autocomplete (`_isbnFromAutocomplete != null`)
  /// - are deja coperta oficială.
  void _scheduleCoverSearch() {
    _coverSearchDebounce?.cancel();
    if (_isbnFromAutocomplete != null) return;
    final title = _titleController.text.trim();
    if (title.length < 2) {
      if (_recommendedCovers.isNotEmpty) {
        setState(() => _recommendedCovers = const []);
      }
      return;
    }
    _coverSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final covers = await ref.read(booksRepositoryProvider).suggestCovers(
              title: title,
              author: _authorController.text.trim(),
            );
        if (!mounted) return;
        setState(() => _recommendedCovers = covers);
      } catch (_) {
        // Ignoră - o eroare de rețea la coperte nu trebuie să blocheze
        // ecranul de adăugare.
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _coverSearchDebounce?.cancel();
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
    _searchDebounce = Timer(const Duration(milliseconds: 200), () async {
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
      if (result.description != null &&
          result.description!.trim().isNotEmpty &&
          _descriptionController.text.isEmpty) {
        final description = result.description!.trim();
        // setText programatic nu trece prin LengthLimitingTextInputFormatter
        // (acela intervine doar la input de la tastatură) - trunchiem manual,
        // altfel câmpul ar afișa un text peste limita permisă la submit.
        _descriptionController.text =
            description.length > 256 ? description.substring(0, 256) : description;
      }
      _isbnFromAutocomplete = result.isbn;
      // La alegerea unei ediții de autocomplete, folosim coperta ei oficială
      // - nu mai are sens să căutăm recomandări suplimentare. Batch 8.
      if (result.coverUrl != null && result.coverUrl!.isNotEmpty) {
        _selectedCoverUrl = result.coverUrl;
      }
      _recommendedCovers = const [];
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
      // `??=`: la un retry după un eșec pe un pas ulterior (poze/preț), NU
      // recreăm anunțul - vezi comentariul de la `_createdUserBook`.
      final userBook = _createdUserBook ??=
          await ref.read(booksRepositoryProvider).addToLibrary(
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
                mainPhotoUrl: _selectedCoverUrl,
              );

      // Coperta recomandată aleasă la +Share apare acum și în galeria
      // anunțului, nu doar ca `mainPhotoUrl` separat.
      if (_selectedCoverUrl != null && !_coverUrlAddedToGallery) {
        await ref.read(booksRepositoryProvider).addPhotoUrl(userBook.id, _selectedCoverUrl!);
        _coverUrlAddedToGallery = true;
      }

      // Pornim de unde am rămas: pozele deja urcate la o încercare anterioară
      // nu se reurcă a doua oară.
      for (var i = _uploadedPhotoUrls.length; i < _photos.length; i++) {
        final url = await ref.read(booksRepositoryProvider).addPhoto(
              userBook.id,
              bytes: await _photos[i].readAsBytes(),
              filename: _photos[i].name,
            );
        _uploadedPhotoUrls.add(url);
      }
      // Dacă user a bifat o poză urcată drept „principală", suprascrie orice
      // copertă externă aleasă anterior. Batch 8.
      final pickedIndex = _mainPhotoIndex;
      if (pickedIndex != null &&
          pickedIndex >= 0 &&
          pickedIndex < _uploadedPhotoUrls.length &&
          _uploadedPhotoUrls[pickedIndex] != null) {
        await ref.read(booksRepositoryProvider)
            .setMainPhoto(userBook.id, _uploadedPhotoUrls[pickedIndex]);
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
        // Cartea creată se întoarce la caller - onboarding-ul o arată ca
        // o confirmare pe ultimul pas, în loc să reafișeze doar CTA-ul gol.
        Navigator.of(context).pop(userBook);
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

  static const _desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDesktop = MediaQuery.of(context).size.width >= _desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addBookTitle),
        actions: isDesktop
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.shareSubmit),
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: isDesktop ? _buildDesktop(context) : _buildMobile(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final l10n = context.l10n;
    final charsLeft = 256 - _descriptionController.text.length;
    return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Poze - sus, cu placeholder mare cu „+"
            _PhotoPicker(
              photos: _photos,
              maxPhotos: _maxPhotos,
              mainPhotoIndex: _mainPhotoIndex,
              onPick: _pickPhotos,
              onRemove: (i) {
                _removePhoto(i);
                // Dacă poza scoasă era cea principală, resetăm indexul.
                if (_mainPhotoIndex == i) {
                  setState(() => _mainPhotoIndex = null);
                } else if (_mainPhotoIndex != null && _mainPhotoIndex! > i) {
                  setState(() => _mainPhotoIndex = _mainPhotoIndex! - 1);
                }
              },
              onSetMain: (i) => setState(() => _mainPhotoIndex = i),
            ),
            const SizedBox(height: 24),

            // 2. Titlu cu autocomplete
            _titleField(context),
            const SizedBox(height: 12),

            // 3. Autor
            TextField(
              controller: _authorController,
              decoration: InputDecoration(labelText: l10n.shareAuthorHint),
            ),
            const SizedBox(height: 12),

            // 3b. Copertă recomandată (Batch 8) - vizibilă doar când user nu
            // a ales din autocomplete (n-are deja coperta oficială).
            _CoverPicker(
              selectedUrl: _selectedCoverUrl,
              recommended: _recommendedCovers,
              onSelect: (url) => setState(() => _selectedCoverUrl = url),
              onClear: () => setState(() => _selectedCoverUrl = null),
            ),

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

            // 5. Descriere - pornește compact (2 linii) și crește pe măsură
            // ce userul scrie, în loc să rezerve dintotdeauna 4 linii goale.
            TextField(
              controller: _descriptionController,
              maxLength: 256,
              minLines: 2,
              maxLines: 6,
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
            ..._priceFields(context),
            const SizedBox(height: 20),

            // 7. Localitate - autocomplete peste toate orașele din România, nu
            // dropdown cu reședințele de județ.
            CityAutocomplete(
              value: _city,
              label: l10n.shareCityHint,
              emptyLabel: l10n.shareCityUnknown,
              onChanged: (value) => setState(() => _city = value),
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

            ..._moreInfoSection(context),

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
        );
  }

  // Layout pe două coloane: coperta/pozele stânga, formularul dreapta - vezi
  // mockup-ul Milestone 20. Publish stă în AppBar, nu la baza paginii.
  Widget _buildDesktop(BuildContext context) {
    final l10n = context.l10n;
    final charsLeft = 256 - _descriptionController.text.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      // Capăt de lățime pe tot rândul, nu doar pe coloana de formular: fără
      // el, `Expanded` umplea tot spațiul rămas pe ecrane late, iar un câmp
      // de titlu ajungea la ~1100px - absurd pentru un input de o linie.
      // 220 (copertă) + 34 (gap) + ~700 (formular) ≈ 954.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 954),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoPicker(
                  photos: _photos,
                  maxPhotos: _maxPhotos,
                  mainPhotoIndex: _mainPhotoIndex,
                  onPick: _pickPhotos,
                  onRemove: (i) {
                    _removePhoto(i);
                    if (_mainPhotoIndex == i) {
                      setState(() => _mainPhotoIndex = null);
                    } else if (_mainPhotoIndex != null && _mainPhotoIndex! > i) {
                      setState(() => _mainPhotoIndex = _mainPhotoIndex! - 1);
                    }
                  },
                  onSetMain: (i) => setState(() => _mainPhotoIndex = i),
                ),
                const SizedBox(height: 20),
                _CoverPicker(
                  selectedUrl: _selectedCoverUrl,
                  recommended: _recommendedCovers,
                  onSelect: (url) => setState(() => _selectedCoverUrl = url),
                  onClear: () => setState(() => _selectedCoverUrl = null),
                ),
              ],
            ),
          ),
          const SizedBox(width: 34),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.shareSectionBook,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.mutedForeground)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _titleField(context)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _authorController,
                        decoration: InputDecoration(labelText: l10n.shareAuthorHint),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _genreController,
                        decoration: InputDecoration(labelText: l10n.shareGenreHint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TagsInput(
                        tags: _tags,
                        controller: _tagInputController,
                        hint: l10n.shareTagsHint,
                        onAdd: _addTag,
                        onRemove: _removeTag,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: TextField(
                        controller: _descriptionController,
                        maxLength: 256,
                        minLines: 3,
                        maxLines: 6,
                        inputFormatters: [LengthLimitingTextInputFormatter(256)],
                        decoration: InputDecoration(
                          labelText: l10n.shareDescriptionHint,
                          counterText: l10n.shareDescriptionCharsLeft(charsLeft),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                Text(l10n.shareSectionListing,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.mutedForeground)),
                const SizedBox(height: 12),
                _ListingModePicker(
                  mode: _listingMode,
                  onChanged: (m) => setState(() => _listingMode = m),
                ),
                ..._priceFields(context),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<BookCondition>(
                        initialValue: _condition,
                        decoration: InputDecoration(labelText: l10n.filtersCondition),
                        items: [
                          for (final c in BookCondition.values)
                            DropdownMenuItem(value: c, child: Text(c.label(l10n))),
                        ],
                        onChanged: (v) => setState(() => _condition = v ?? _condition),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: CityAutocomplete(
                        value: _city,
                        label: l10n.shareCityHint,
                        emptyLabel: l10n.shareCityUnknown,
                        onChanged: (value) => setState(() => _city = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._moreInfoSection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleField(BuildContext context) {
    final l10n = context.l10n;
    return Autocomplete<ExternalBookResult>(
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
                      width: (MediaQuery.of(context).size.width - 32).clamp(0, 420),
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
            );
  }

  // 6. Mod de listare - câmpurile de preț/licitație, comune ambelor layout-uri.
  List<Widget> _priceFields(BuildContext context) {
    final l10n = context.l10n;
    if (_listingMode != _ListingMode.sale && _listingMode != _ListingMode.auction) {
      return const [];
    }
    return [
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
            ];
  }

  // 8. „Mai multe informații" - collapsible, comun ambelor layout-uri.
  List<Widget> _moreInfoSection(BuildContext context) {
    final l10n = context.l10n;
    return [
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
    ];
  }
}

/// Placeholder mare cu „+" + thumbnails cu poze urcate + „X" de ștergere.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.maxPhotos,
    required this.onPick,
    required this.onRemove,
    this.mainPhotoIndex,
    this.onSetMain,
  });
  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onPick;
  final void Function(int) onRemove;

  /// Indexul pozei bifate ca „principală". Când e null și există poze, tap
  /// pe steaua unei poze o marchează.
  final int? mainPhotoIndex;
  final void Function(int)? onSetMain;

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
                    if (onSetMain != null)
                      Positioned(
                        left: 2,
                        bottom: 2,
                        child: GestureDetector(
                          onTap: () => onSetMain!(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: mainPhotoIndex == index
                                  ? AppColors.accent
                                  : Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              mainPhotoIndex == index
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (onSetMain != null && photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                context.l10n.shareMainPhotoHint,
                style: TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground),
              ),
            ),
        ],
      ],
    );
  }
}

/// Tag-uri propuse, ca punct de plecare pentru cine nu știe ce să scrie. Nu
/// limitează nimic - userul poate în continuare adăuga orice tag manual.
const _suggestedTags = [
  'fantasy',
  'SF',
  'thriller',
  'polițist',
  'romantic',
  'dezvoltare personală',
  'biografie',
  'istorie',
  'copii',
  'young adult',
  'clasic',
  'poezie',
  'bestseller',
  'ediție veche',
  'carte rară',
  'ilustrată',
  'în engleză',
  'serie completă',
];

/// Câmp text + chip-uri; enter/virgulă adaugă tag-ul curent. Sub câmp apar
/// sugestii pe care userul le poate alege cu un tap.
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
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final t = tags[index];
                return Chip(
                  label: Text(t),
                  onDeleted: () => onRemove(t),
                );
              },
            ),
          ),
        ],
        // Doar sugestiile neadăugate încă, și doar cât timp mai e loc (max 5
        // tag-uri) - altfel userul ar apăsa pe chipuri fără efect. Scroll
        // orizontal, nu `Wrap` - cele ~18 sugestii se întindeau pe 3-4 rânduri.
        if (tags.length < 5) ...[
          const SizedBox(height: 10),
          Text(
            context.l10n.shareTagsSuggestions,
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Builder(builder: (context) {
            final available = _suggestedTags.where((s) => !tags.contains(s)).toList();
            return SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: available.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final suggestion = available[index];
                  return ActionChip(
                    label: Text(suggestion),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onAdd(suggestion),
                  );
                },
              ),
            );
          }),
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

/// Selector „Coperta cărții" (Batch 8): dacă user a ales deja o copertă,
/// o afișăm mare cu buton X pentru dezalegere. Altfel, arătăm până la 4
/// miniaturi „recomandate" (returnate de /books/covers pe baza titlului
/// și autorului tastate). Fără copertă selectată și fără recomandări nu
/// randăm nimic - secțiunea rămâne invizibilă.
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.selectedUrl,
    required this.recommended,
    required this.onSelect,
    required this.onClear,
  });

  final String? selectedUrl;
  final List<String> recommended;
  final void Function(String url) onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (selectedUrl == null && recommended.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedUrl != null
                ? l10n.shareCoverSelected
                : l10n.shareCoverRecommended,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          if (selectedUrl != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    selectedUrl!,
                    width: 96,
                    height: 128,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 96,
                      height: 128,
                      color: AppColors.muted,
                      child: Icon(Icons.broken_image,
                          color: AppColors.mutedForeground),
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: onClear,
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
            )
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommended.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = recommended[index];
                  return GestureDetector(
                    onTap: () => onSelect(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 90,
                        height: 128,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 90,
                          height: 128,
                          color: AppColors.muted,
                          child: Icon(Icons.broken_image,
                              color: AppColors.mutedForeground),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
