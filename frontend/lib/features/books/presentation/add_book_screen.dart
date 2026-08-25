import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../shared/utils/cover_proxy.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/my_library_controller.dart';
import '../data/auctions_repository.dart';
import '../data/books_repository.dart';
import '../data/genre_tag_suggestions.dart';

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
  /// Pretul optional „sau vinde cu X lei" pentru anunturile de tip Schimb -
  /// vezi UserBook.swapSalePrice. Nu transforma anuntul intr-unul de Vanzare.
  final _swapSalePriceController = TextEditingController();
  final _pageCountController = TextEditingController();
  final _publishedYearController = TextEditingController();
  final _editionYearController = TextEditingController();
  final _publisherController = TextEditingController();
  final _seriesController = TextEditingController();
  final _seriesNumberController = TextEditingController();

  final List<String> _tags = [];
  final List<XFile> _photos = [];

  bool _isSubmitting = false;
  bool _showMoreInfo = false;
  BookCondition _condition = BookCondition.buna;
  bool _isHardcover = false;
  _ListingMode _listingMode = _ListingMode.swap;
  int _auctionDurationHours = 24;
  bool _isNegotiable = true;
  /// Toggle-ul „Sau vinde cu..." de pe modul Schimb.
  bool _sellOnSwap = false;
  /// True cat timp o cautare de titlu e in zbor - schimba helperText-ul din
  /// „Incepe sa scrii ca sa vezi sugestii" in „Se cauta titlul...".
  bool _titleSearching = false;
  /// Ultimul gen pentru care am recalculat sugestiile de taguri.
  String _lastGenreForTags = '';

  /// Subiectele reale ale cărții alese din autocomplete (Open Library
  /// `subjects` / Google Books `categories`). Când sunt disponibile, înlocuiesc
  /// sugestiile statice pe gen din genre_tag_suggestions.dart; gol => cădem
  /// înapoi pe acelea (ex. carte scrisă manual, fără potrivire externă).
  List<String> _subjectTags = const [];

  /// True cât timp e în zbor apelul de detalii complete pentru cartea aleasă.
  /// Un singur apel, la selecție - nu pe fiecare tastă.
  bool _detailsLoading = false;

  /// Discriminăm răspunsurile întârziate: dacă userul alege repede altă
  /// sugestie, răspunsul celei vechi nu mai are voie să scrie în formular.
  int _detailsRequestId = 0;
  String? _city;
  String? _isbnFromAutocomplete;

  Timer? _searchDebounce;
  final _genreFocus = FocusNode();

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
    // Sugestiile de taguri depind de genul ales - vezi genre_tag_suggestions.dart.
    _genreController.addListener(_onGenreChanged);
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
    _genreFocus.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    _priceController.dispose();
    _swapSalePriceController.dispose();
    _pageCountController.dispose();
    _publishedYearController.dispose();
    _editionYearController.dispose();
    _publisherController.dispose();
    _seriesController.dispose();
    _seriesNumberController.dispose();
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

  void _onGenreChanged() {
    final genre = _genreController.text.trim();
    if (genre == _lastGenreForTags) return;
    _lastGenreForTags = genre;
    if (mounted) setState(() {});
  }

  /// `optionsBuilder` poate fi apelat in timpul unui build al campului, deci
  /// nu putem chema `setState` sincron - amanam pe frame-ul urmator.
  void _setTitleSearching(bool value) {
    if (_titleSearching == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _titleSearching != value) {
        setState(() => _titleSearching = value);
      }
    });
  }

  /// Completer-ul cererii de titlu aflate in asteptare. Il tinem ca sa-l
  /// putem incheia (cu lista goala) cand o tasta noua anuleaza timer-ul -
  /// altfel `Autocomplete` ramanea cu un Future care nu se rezolva niciodata.
  Completer<Iterable<ExternalBookResult>>? _pendingTitleSearch;

  Future<Iterable<ExternalBookResult>> _titleAutocomplete(String query) async {
    if (query.trim().length < 2) {
      _setTitleSearching(false);
      return const [];
    }
    // Debouncing la nivel de tastare: daca alta cerere e programata, o
    // anulam - nu vrem 10 request-uri pentru „Harry Potter". 120ms e sub
    // pragul la care userul percepe o pauza, dar tot grupeaza tastele rapide.
    _searchDebounce?.cancel();
    final pending = _pendingTitleSearch;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const []);
    }
    _setTitleSearching(true);
    final completer = Completer<Iterable<ExternalBookResult>>();
    _pendingTitleSearch = completer;
    _searchDebounce = Timer(const Duration(milliseconds: 120), () async {
      try {
        final results =
            await ref.read(booksRepositoryProvider).searchExternal(query.trim());
        if (!completer.isCompleted) completer.complete(results);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(const []);
      } finally {
        if (identical(_pendingTitleSearch, completer)) _setTitleSearching(false);
      }
    });
    return completer.future;
  }

  /// Autocomplete pe gen: lista curata propusa de aplicatie (aceeasi ca in
  /// backend/src/common/constants/book-genres.ts) + genurile care exista deja
  /// in catalog, filtrate dupa ce a scris userul. Campul ramane text liber.
  Future<Iterable<String>> _genreOptions(String query) async {
    final q = query.trim().toLowerCase();
    final options = suggestedGenres
        .where((g) => q.isEmpty || g.toLowerCase().contains(q))
        .toList();
    if (q.length >= 2) {
      try {
        final remote =
            await ref.read(booksRepositoryProvider).getGenres(query: query.trim());
        for (final g in remote.map((e) => e.genre)) {
          if (!options.any((o) => o.toLowerCase() == g.toLowerCase())) {
            options.add(g);
          }
        }
      } catch (_) {
        // O eroare de retea la sugestii nu trebuie sa blocheze scrierea.
      }
    }
    return options.take(10);
  }

  Widget _genreField(BuildContext context) {
    final l10n = context.l10n;
    // RawAutocomplete (nu Autocomplete) ca sa putem folosi direct
    // `_genreController` - altfel ar trebui sincronizat manual, ca la titlu.
    return RawAutocomplete<String>(
      textEditingController: _genreController,
      focusNode: _genreFocus,
      optionsBuilder: (value) => _genreOptions(value.text),
      onSelected: (_) => setState(() {}),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          textAlignVertical: TextAlignVertical.center,
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: l10n.shareGenreHint),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: (MediaQuery.of(context).size.width - 32).clamp(0, 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option, maxLines: 1),
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

  /// Deschide popup-ul centrat cu cărțile din biblioteca proprie a userului
  /// (`myLibraryControllerProvider`) - alternativă la autocomplete-ul extern
  /// pentru cine relistează o carte pe care a mai avut-o pe platformă.
  Future<void> _openMyBooksPicker() async {
    final selected = await showDialog<UserBook>(
      context: context,
      builder: (_) => const _MyBooksPickerDialog(),
    );
    if (selected != null) _applyMyBook(selected);
  }

  /// Completează câmpurile de mai jos cu detaliile unei cărți deja listate de
  /// user - simetric cu `_applySuggestion`, dar sursa e propria bibliotecă,
  /// nu căutarea externă.
  void _applyMyBook(UserBook userBook) {
    final book = userBook.book;
    setState(() {
      _titleController.text = book.title;
      _authorController.text = book.author ?? '';
      if (book.genre != null && book.genre!.isNotEmpty) {
        _genreController.text = book.genre!;
      }
      final description = (userBook.description?.isNotEmpty ?? false)
          ? userBook.description!
          : (book.description ?? '');
      _descriptionController.text =
          description.length > 256 ? description.substring(0, 256) : description;
      _tags
        ..clear()
        ..addAll(userBook.tags.take(5));
      if (userBook.city != null && userBook.city!.isNotEmpty) {
        _city = userBook.city;
      }
      if (book.publisher != null && book.publisher!.isNotEmpty) {
        _publisherController.text = book.publisher!;
      }
      if (book.publishedYear != null) {
        _publishedYearController.text = book.publishedYear!.toString();
      }
      if (book.pageCount != null) {
        _pageCountController.text = book.pageCount!.toString();
      }
      if (book.series != null && book.series!.isNotEmpty) {
        _seriesController.text = book.series!;
      }
      if (book.seriesNumber != null) {
        _seriesNumberController.text = book.seriesNumber!.toString();
      }
      _condition = userBook.condition;
      _isHardcover = userBook.isHardcover;
      _isbnFromAutocomplete = book.isbn;
      final cover = userBook.primaryImageUrl;
      if (cover != null && cover.isNotEmpty) {
        _selectedCoverUrl = cover;
        _recommendedCovers = [cover];
      }
    });
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
      // Subiectele venite gratis în rândul de căutare - sunt înlocuite imediat
      // ce răspunde `_fetchFullDetails`, dacă acela găsește mai multe.
      if (result.subjects.isNotEmpty) _subjectTags = result.subjects;
      _isbnFromAutocomplete = result.isbn;
      // Coperta ediției alese e preselectată, dar NU e neapărat cea mai
      // reprezentativă (poate fi un scan slab sau o ediție obscură) - alte
      // ediții ale aceluiași titlu au adesea coperte mai bune. Rămâne
      // preselectată, dar userul poate alege alta din `_CoverPicker` -
      // opțiunile se completează mai jos, în `_fetchFullDetails`.
      if (result.coverUrl != null && result.coverUrl!.isNotEmpty) {
        _selectedCoverUrl = result.coverUrl;
        _recommendedCovers = [result.coverUrl!];
      } else {
        _recommendedCovers = const [];
      }
    });
    unawaited(_fetchFullDetails(result));
  }

  /// Singurul apel „scump" din fluxul de autocomplete: după ce userul alege o
  /// carte anume, cerem detaliile complete (descriere + subiecte) ȘI coperte
  /// alternative (alte ediții ale aceluiași titlu au adesea coperte diferite,
  /// uneori mai reprezentative decât ediția aleasă). Rezultatele de căutare
  /// rămân subțiri intenționat - vezi `_titleAutocomplete`.
  Future<void> _fetchFullDetails(ExternalBookResult picked) async {
    final requestId = ++_detailsRequestId;
    setState(() => _detailsLoading = true);
    try {
      final results = await Future.wait([
        ref.read(booksRepositoryProvider).lookupDetails(
              isbn: picked.isbn,
              title: picked.title,
              author: picked.author,
            ),
        ref.read(booksRepositoryProvider).suggestCovers(
              title: picked.title,
              author: picked.author,
            ),
      ]);
      // Alt titlu ales între timp (sau ecran închis) - ignorăm răspunsul.
      if (!mounted || requestId != _detailsRequestId) return;
      final full = results[0] as ExternalBookResult?;
      final coverOptions = results[1] as List<String>;
      setState(() {
        if (full != null) {
          // Descrierea din sursa externă NU se pune în nota personală a
          // proprietarului (`_descriptionController`, rămâne liberă pentru
          // userul care scrie ceva propriu) - descrierea catalogului
          // ("Despre carte") vine separat, server-side, la crearea cărții
          // (vezi `findOrCreateBook` din books.service.ts).
          if (full.subjects.isNotEmpty) _subjectTags = full.subjects;
          if (full.genre != null && _genreController.text.trim().isEmpty) {
            _genreController.text = full.genre!;
          }
        }
        if (coverOptions.isNotEmpty) {
          // Coperta deja preselectată (dacă a venit vreuna din autocomplete)
          // rămâne prima în listă, restul se adaugă fără duplicate.
          final merged = [
            ...?_selectedCoverUrl != null ? [_selectedCoverUrl!] : null,
            ...coverOptions.where((c) => c != _selectedCoverUrl),
          ];
          _recommendedCovers = merged;
        }
      });
    } catch (_) {
      // O eroare de rețea aici nu blochează nimic - formularul rămâne
      // complet utilizabil cu datele din rândul de autocomplete.
    } finally {
      if (mounted && requestId == _detailsRequestId) {
        setState(() => _detailsLoading = false);
      }
    }
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
    final swapSalePrice = _listingMode == _ListingMode.swap && _sellOnSwap
        ? double.tryParse(
            _swapSalePriceController.text.trim().replaceAll(',', '.'))
        : null;
    if (_listingMode == _ListingMode.swap &&
        _sellOnSwap &&
        swapSalePrice == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addBookInvalidPrice)));
      return;
    }

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
                series: _seriesController.text.trim().isEmpty
                    ? null
                    : _seriesController.text.trim(),
                seriesNumber: int.tryParse(_seriesNumberController.text.trim()),
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
      if (_listingMode == _ListingMode.swap && swapSalePrice != null) {
        await ref
            .read(booksRepositoryProvider)
            .setSwapSalePrice(userBook.id, swapSalePrice);
      } else if (_listingMode == _ListingMode.sale) {
        await ref.read(booksRepositoryProvider).markForSale(
              userBook.id,
              salePrice: salePrice!,
              isNegotiable: _isNegotiable,
            );
      } else if (_listingMode == _ListingMode.auction) {
        await ref.read(auctionsRepositoryProvider).createAuction(
              userBook.id,
              startingPrice: salePrice!,
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
        // Cu valoare, nu gol: onboarding-ul (vezi
        // OnboardingFlowScreen._openAddBook) așteaptă cartea creată înapoi ca
        // să o afișeze în locul cardului CTA - un pop() fără argument o lăsa
        // mereu null, iar cardul nu se schimba niciodată după adăugare.
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

            // 2. Titlu cu autocomplete + buton „Din cărțile mele"
            _titleFieldWithMyBooksButton(context),
            const SizedBox(height: 12),

            // 3. Autor
            TextField(
              textAlignVertical: TextAlignVertical.center,
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
            _genreField(context),
            const SizedBox(height: 12),
            _TagsInput(
              tags: _tags,
              controller: _tagInputController,
              hint: l10n.shareTagsHint,
              genre: _genreController.text,
              subjects: _subjectTags,
              loadingSubjects: _detailsLoading,
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
                    Expanded(flex: 2, child: _titleFieldWithMyBooksButton(context)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        textAlignVertical: TextAlignVertical.center,
                        controller: _authorController,
                        decoration: InputDecoration(labelText: l10n.shareAuthorHint),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _genreField(context)),
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
                        genre: _genreController.text,
                        subjects: _subjectTags,
                        loadingSubjects: _detailsLoading,
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
                          suffixIcon:
                              _detailsLoading ? const _FieldSpinner() : null,
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

  // Câmpul de titlu (rămâne pe toată lățimea rândului) + sigla ShelfShare în
  // dreapta lui, ca buton compact care deschide popup-ul centrat din
  // `_MyBooksPickerDialog` - aceeași siglă (cerc accent + menu_book_rounded)
  // ca în header-ul sidebar-ului și în login_screen, nu un buton nou cu text.
  Widget _titleFieldWithMyBooksButton(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _titleField(context)),
        const SizedBox(width: 10),
        // Înălțime fixă = cutia standard M3 a câmpului de text (contentPadding
        // 16+16 din AppTheme + linia de text de 24 = 56), NU tot rândul (care
        // include și textul ajutător de sub cutie). Cu `Padding(top: 4)`
        // butonul era calibrat pentru fostul buton-pilulă, mai scund - de
        // când sigla e un cerc de 42 (padding 10 + icon 22 + padding 10), cei
        // 4px fixi nu-l mai centrau, ci îl împingeau vizibil spre marginea de
        // sus a câmpului. `Center` recalculează mereu offsetul corect,
        // indiferent de dimensiunea siglei.
        SizedBox(
          height: 56,
          child: Center(
            child: Tooltip(
              message: context.l10n.shareFromMyBooks,
              child: Material(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _openMyBooksPicker,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.menu_book_rounded,
                        color: AppColors.accent, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
                // Guard obligatoriu: fieldViewBuilder rulează la ORICE
                // rebuild al ecranului (nu doar o dată), inclusiv în timp ce
                // userul tastează (ex. la fiecare toggle al `_titleSearching`
                // din debounce-ul de căutare). O atribuire necondiționată aici
                // rescria `controller.text` chiar când era deja identic,
                // ceea ce reseta selecția la "select all" - litera următoare
                // tastată ștergea tot ce scrisese userul până atunci.
                if (controller.text != _titleController.text) {
                  controller.text = _titleController.text;
                }
                controller.addListener(() {
                  if (_titleController.text != controller.text) {
                    _titleController.text = controller.text;
                  }
                });
                return TextField(
                  textAlignVertical: TextAlignVertical.center,
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: l10n.shareTitleHint,
                    helperText: _titleSearching
                        ? l10n.shareTitleSearching
                        : l10n.shareTitleAutocomplete,
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
                          final sourceLabel = option.source == 'google_books'
                              ? 'Via Google Books'
                              : 'Via fallback Open Library';
                          return ListTile(
                            dense: true,
                            title: Text(option.title, maxLines: 1),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (option.author != null)
                                  Text(option.author!, maxLines: 1),
                                Text(
                                  sourceLabel,
                                  maxLines: 1,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.mutedForeground),
                                ),
                              ],
                            ),
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
    // Schimb: optional „sau vinde cu X lei" - anuntul ramane de tip Schimb
    // (isForSale false), dar accepta si oferte in bani, iar pe pagina cartii
    // apar doua butoane distincte. Vezi UserBook.swapSalePrice.
    if (_listingMode == _ListingMode.swap) {
      return [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shareSwapAlsoSell),
          value: _sellOnSwap,
          onChanged: (v) => setState(() => _sellOnSwap = v),
        ),
        if (_sellOnSwap)
          TextField(
            textAlignVertical: TextAlignVertical.center,
            controller: _swapSalePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.shareSwapAlsoSellPrice,
              suffixText: 'lei',
            ),
          ),
      ];
    }
    if (_listingMode != _ListingMode.sale && _listingMode != _ListingMode.auction) {
      return const [];
    }
    return [
      const SizedBox(height: 12),
      TextField(
                textAlignVertical: TextAlignVertical.center,
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
                textAlignVertical: TextAlignVertical.center,
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
                textAlignVertical: TextAlignVertical.center,
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
                textAlignVertical: TextAlignVertical.center,
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
                textAlignVertical: TextAlignVertical.center,
                controller: _publisherController,
                decoration: InputDecoration(labelText: l10n.sharePublisher),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      controller: _seriesController,
                      decoration: InputDecoration(labelText: l10n.shareSeriesName),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      controller: _seriesNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l10n.shareSeriesNumber),
                    ),
                  ),
                ],
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

/// Spinner mic pentru `suffixIcon`, cât timp aducem detaliile complete ale
/// cărții alese din autocomplete. Nu blochează câmpul - userul poate scrie în
/// continuare, iar dacă a scris ceva nu-i suprascriem textul (vezi
/// `_prefillDescription`).
class _FieldSpinner extends StatelessWidget {
  const _FieldSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
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
    required this.genre,
    required this.subjects,
    required this.loadingSubjects,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> tags;
  final TextEditingController controller;
  final String hint;
  /// Genul scris/ales de user - sugestiile de taguri se prioritizeaza dupa el
  /// (vezi genre_tag_suggestions.dart). Gol => lista generala.
  final String genre;

  /// Subiectele reale ale cartii alese din autocomplete. Cand exista, iau
  /// locul listei statice pe gen - sunt specifice cartii, nu genului.
  final List<String> subjects;

  /// True cat timp asteptam detaliile complete ale cartii alese; afisam un
  /// spinner mic langa eticheta de sugestii, fara sa blocam campul.
  final bool loadingSubjects;
  final void Function(String) onAdd;
  final void Function(String) onRemove;

  /// Cate sugestii afisam in total (scroll orizontal) - lista de subiecte
  /// poate veni cu 20 de intrari, iar peste ~15 chip-uri userul oricum nu mai
  /// deruleaza.
  static const _maxVisibleSuggestions = 15;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          textAlignVertical: TextAlignVertical.center,
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
          Row(
            children: [
              Text(
                context.l10n.shareTagsSuggestions,
                style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
              ),
              if (loadingSubjects) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Builder(builder: (context) {
            // Cand avem subiectele reale ale cartii (Open Library / Google
            // Books) le folosim in locul listei statice pe gen - sunt mult mai
            // specifice. Fara ele (carte scrisa manual, fara potrivire) cadem
            // pe maparea gen -> taguri. Lista generala ramane la coada in
            // ambele cazuri, ca sursa de taguri „de forma" (stare, editie).
            final primary =
                subjects.isNotEmpty ? subjects : tagSuggestionsForGenre(genre);
            final available = <String>[];
            for (final s in [...primary, ..._suggestedTags]) {
              if (available.length >= _maxVisibleSuggestions) break;
              if (!tags.contains(s) && !available.contains(s)) available.add(s);
            }
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

/// Selector „Coperta cărții": arată mereu opțiunile ca miniaturi
/// răsfoibile orizontal (nu doar coperta selectată mare, fără alternative) -
/// coperta oficială a unei ediții anume nu e mereu cea mai reprezentativă
/// (scan slab, ediție obscură), iar alte ediții ale aceluiași titlu au adesea
/// coperte diferite. Cea selectată e evidențiată cu bordură; un buton
/// „Elimină" separat scoate complet alegerea (fallback pe prima poză proprie
/// urcată, apoi nimic). Fără copertă selectată și fără recomandări, secțiunea
/// rămâne invizibilă.
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
    // Coperta selectată apare mereu printre opțiuni, chiar dacă din vreun
    // motiv n-a mai ajuns și în `recommended` - altfel userul ar vedea doar
    // alternative, fără să știe care e alegerea curentă.
    final options = [
      if (selectedUrl != null && !recommended.contains(selectedUrl)) selectedUrl!,
      ...recommended,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                options.length > 1
                    ? l10n.shareCoverChooseOne
                    : selectedUrl != null
                        ? l10n.shareCoverSelected
                        : l10n.shareCoverRecommended,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (selectedUrl != null) ...[
                const Spacer(),
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: Text(l10n.shareCoverRemove),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final url = options[index];
                final isSelected = url == selectedUrl;
                return GestureDetector(
                  onTap: () => onSelect(url),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 3)
                          : null,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      // coverProxyUrl: coperțile Google Books nu trimit CORS,
                      // vezi cover_proxy.dart - fără el, fetch-ul de imagine
                      // eșua silențios pe Flutter Web și cădea pe broken_image.
                      child: CachedNetworkImage(
                        imageUrl: coverProxyUrl(url)!,
                        width: 88,
                        height: 122,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          width: 88,
                          height: 122,
                          color: AppColors.muted,
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: 88,
                          height: 122,
                          color: AppColors.muted,
                          child: Icon(Icons.broken_image,
                              color: AppColors.mutedForeground),
                        ),
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

/// Popup centrat pe ecran (nu panou lateral) cu cărțile din biblioteca
/// proprie a userului - alegerea uneia completează câmpurile de mai jos cu
/// detaliile ei (vezi `_AddBookScreenState._applyMyBook`). `showDialog` cu
/// `Dialog` centrează implicit pe orice mărime de ecran.
class _MyBooksPickerDialog extends ConsumerWidget {
  const _MyBooksPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final asyncBooks = ref.watch(myLibraryControllerProvider);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.shareChooseFromMyBooks,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              Flexible(
                child: asyncBooks.when(
                  data: (books) {
                    final active =
                        books.where((b) => b.deletedAt == null).toList();
                    if (active.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          l10n.shareNoBooksInMyLibrary,
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 4),
                      itemCount: active.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final userBook = active[index];
                        final book = userBook.book;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: BookCover(
                            url: userBook.primaryImageUrl,
                            title: book.title,
                            width: 44,
                            height: 60,
                            borderRadius: 6,
                          ),
                          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: book.author != null
                              ? Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(userBook),
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      l10n.addBookGenericError,
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
