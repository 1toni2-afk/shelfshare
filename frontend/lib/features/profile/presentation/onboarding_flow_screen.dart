import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/city_autocomplete.dart';
import '../../book_match/data/book_match_repository.dart';
import '../../book_match/presentation/book_match_screen.dart';
import '../../books/presentation/add_book_screen.dart';
import '../../../shared/utils/genre_localization.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user_book.dart';
import '../application/profile_controller.dart';
import '../data/profile_repository.dart';
import 'onboarding_illustrations.dart';

const _kTotalSteps = 7;
const _kReadingPaces = ['1', '2-3', '4+'];
const _kLanguagePreset = ['Română', 'English', 'Magyar', 'Deutsch', 'Français', 'Español', 'Italiano'];
const _kPurposes = ['swap', 'sell', 'discover', 'all'];

final _onboardingGenresProvider = FutureProvider<List<String>>((ref) {
  return ref.read(profileRepositoryProvider).getSurveyGenres();
});

/// Wizard-ul de onboarding, arătat o singură dată la primul login (vezi
/// redirect-ul din app_router.dart). Pornește cu pasul -1 (panel de bun venit,
/// doar informativ) urmat de pasul 0 (nume + username, obligatoriu - vezi
/// comentariul de acolo); niciunul din astea două nu are Skip/Back. Restul
/// pașilor au Skip și Back. Răspunsurile de la pașii 1-4 stau doar în state
/// local și se salvează o singură dată, la finalul wizard-ului (pasul 6) -
/// așa router-ul nu ne scoate din mijlocul fluxului, iar Back nu are nimic de
/// anulat pe rețea.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  late int _step;

  // Pasul 0 - username
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _nameVisible = true;
  bool _savingStep0 = false;
  String? _step0Error;

  // Pasul 1 - genuri
  final _selectedGenres = <String>{};

  // Pasul 2 - frecvență
  String? _readingPace;

  // Pasul 3 - locație + limbi
  String? _city;
  final _selectedLanguages = <String>{'Română'};

  // Pasul 4 - scop
  String? _purpose;

  // Pasul 6 - prima carte adăugată în wizard (dacă userul a folosit CTA-ul),
  // afișată ca o confirmare pe ecran, nu doar un card gol de „adaugă o carte".
  //
  // Ținem `Book`, nu `UserBook`: cele două rute din AddBookScreen întorc
  // lucruri diferite - listarea creează un UserBook (anunț), iar „add to
  // shelf" doar o intrare de raft, deci doar cartea din catalog. Cardul de
  // confirmare are nevoie de aceleași câmpuri în ambele cazuri.
  Book? _addedBook;
  String? _addedBookImageUrl;

  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Dacă username-ul e deja setat (ex. userul a închis aplicația la mijlocul
    // wizard-ului și a revenit), pornim direct de la pasul următor - fără
    // panelul de bun venit (pasul -1), care are sens doar la prima intrare.
    final user = ref.read(profileControllerProvider).value;
    _step = user?.username != null ? 1 : -1;
    // Book Match e pasul 5, la câteva zeci de secunde de aici. Citirea
    // providerului pornește aducerea primului lot de carduri ACUM, în paralel
    // cu completarea datelor, ca pasul de swipe să nu mai deschidă cu spinner.
    ref.read(bookMatchPrefetchProvider);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _back() => setState(() => _step--);
  void _next() => setState(() => _step++);

  Future<void> _submitStep0() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _savingStep0 = true;
      _step0Error = null;
    });
    try {
      final name = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      await ref.read(profileControllerProvider.notifier).updateProfile(
            name: name,
            username: _usernameController.text.trim(),
            nameVisible: _nameVisible,
          );
      if (mounted) _next();
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : context.l10n.onboardingGenericError;
        setState(() => _step0Error = message);
      }
    } finally {
      if (mounted) setState(() => _savingStep0 = false);
    }
  }

  /// Ultimul pas al wizard-ului. Ordinea contează: chestionarul e cel care
  /// pune `readingSurveyCompletedAt`, adică singurul lucru fără care routerul
  /// ne trimite înapoi la /onboarding (vezi redirect-ul din app_router.dart).
  ///
  /// Orașul și limbile se salvează separat și NU au voie să blocheze
  /// finalizarea: un PATCH picat pe ele (validare de oraș, rețea) lăsa userul
  /// captiv în wizard - apăsa Continue, primea eroare și nu mai putea ieși
  /// niciodată, deși partea obligatorie (username) era deja salvată.
  /// La fel, dacă chestionarul a intrat pe server dar răspunsul nu s-a putut
  /// aplica local, recitim profilul: dacă serverul îl are marcat ca parcurs,
  /// plecăm mai departe în loc să reîncercăm la infinit.
  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      try {
        await ref.read(profileControllerProvider.notifier).updateProfile(
              city: _city,
              languages: _selectedLanguages.toList(),
            );
      } catch (_) {
        // Detalii opționale de profil - se pot completa oricând din Setări.
      }

      try {
        await ref.read(profileControllerProvider.notifier).saveReadingSurvey(
              favoriteGenres: _selectedGenres.toList(),
              readingPace: _readingPace,
              purpose: _purpose,
            );
      } catch (_) {
        await ref.read(profileControllerProvider.notifier).refresh();
        final user = ref.read(profileControllerProvider).value;
        if (user?.readingSurveyCompletedAt == null) rethrow;
      }

      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.surveySaveError)));
      }
    } finally {
      // În `finally`, nu doar pe ramura de eroare: altfel orice ieșire
      // neprevăzută (inclusiv un `context.go` care nu duce nicăieri fiindcă
      // redirect-ul routerului a mutat deja ecranul) lăsa butonul blocat pe
      // spinner, fără nicio cale de a-l reapăsa.
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_step > 0) _buildProgress(),
            Expanded(child: _buildStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.onboardingFlowStepLabel(_step, _kTotalSteps - 1),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i < _kTotalSteps; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: i <= _step ? 1 : 0,
                      minHeight: 3,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                        i <= _step ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case -1:
        return _WelcomePanel(onContinue: _next);
      case 0:
        return _Step0Username(
          formKey: _formKey,
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          usernameController: _usernameController,
          nameVisible: _nameVisible,
          onNameVisibleChanged: (v) => setState(() => _nameVisible = v),
          saving: _savingStep0,
          error: _step0Error,
          onSubmit: _submitStep0,
        );
      case 1:
        return _wizardScaffold(
          title: context.l10n.onboardingFlowGenresTitle,
          subtitle: context.l10n.onboardingFlowGenresSubtitle,
          content: _buildGenresContent(),
        );
      case 2:
        return _wizardScaffold(
          title: context.l10n.onboardingFlowFrequencyTitle,
          subtitle: context.l10n.onboardingFlowFrequencySubtitle,
          content: _buildFrequencyContent(),
        );
      case 3:
        return _wizardScaffold(
          title: context.l10n.onboardingFlowLocationTitle,
          subtitle: context.l10n.onboardingFlowLocationSubtitle,
          content: _buildLocationContent(),
        );
      case 4:
        return _wizardScaffold(
          title: context.l10n.onboardingFlowPurposeTitle,
          subtitle: context.l10n.onboardingFlowPurposeSubtitle,
          content: _buildPurposeContent(),
        );
      case 5:
        return _wizardScaffold(
          title: context.l10n.onboardingFlowBookMatchTitle,
          subtitle: context.l10n.onboardingFlowBookMatchSubtitle,
          content: const BookMatchScreen(embedded: true),
          scrollable: false,
          compact: true,
          hideSkipLink: true,
        );
      default:
        return _wizardScaffold(
          title: context.l10n.onboardingFlowAddBooksTitle,
          subtitle: context.l10n.onboardingFlowAddBooksSubtitle,
          content: _buildAddBooksContent(),
          isLastStep: true,
        );
    }
  }

  Widget _wizardScaffold({
    required String title,
    required String subtitle,
    required Widget content,
    bool scrollable = true,
    bool isLastStep = false,
    // BookMatch (pasul 5) are nevoie de tot spațiul vertical disponibil pentru
    // cardul de swipe - titlul mare + subtitlu (ca la restul pașilor) lăsau
    // prea puțin loc, iar coperta cărții se micșora ca să încapă. Varianta
    // compactă renunță la subtitlu și reduce titlul/padding-ul de sus.
    bool compact = false,
    // BookMatch (pasul 5) are deja propriul link „Skip" în interiorul
    // cardului de swipe (vezi BookMatchScreen._buildActions) - linkul
    // generic de Skip din footer ar fi un al doilea link identic, redundant.
    bool hideSkipLink = false,
  }) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text(
          title,
          style: compact
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.headlineSmall,
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
        SizedBox(height: compact ? 8 : 24),
        scrollable ? content : Expanded(child: content),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, compact ? 12 : 20, 24, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: scrollable ? SingleChildScrollView(child: body) : body,
              ),
            ),
          ),
        ),
        _buildFooter(isLastStep: isLastStep, hideSkipLink: hideSkipLink),
      ],
    );
  }

  // Lățimea standard a unui IconButton Material (48) - folosită și pentru
  // spacer-ul de sub săgeata Back, ca textul Skip să fie centrat sub
  // Continue, nu sub tot rândul (Back + Continue).
  static const _backButtonWidth = 48.0;

  Widget _buildFooter({required bool isLastStep, bool hideSkipLink = false}) {
    final continueButton = FilledButton(
      onPressed: _finishing ? null : () => isLastStep ? _finish() : _next(),
      child: _finishing
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryForeground,
              ),
            )
          : Text(isLastStep ? context.l10n.onboardingFlowFinish : context.l10n.commonContinue),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.onboardingFlowBackTooltip,
                    onPressed: _finishing ? null : _back,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: continueButton),
                ],
              ),
              if (!hideSkipLink)
                Row(
                  children: [
                    const SizedBox(width: _backButtonWidth + 8),
                    Expanded(
                      child: Center(
                        child: TextButton(
                          onPressed: _finishing ? null : () => isLastStep ? _finish() : _next(),
                          child: Text(context.l10n.onboardingFlowSkip),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenresContent() {
    final genresAsync = ref.watch(_onboardingGenresProvider);
    return genresAsync.when(
      data: (genres) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final genre in genres)
            FilterChip(
              label: Text(localizedGenre(context, genre)),
              selected: _selectedGenres.contains(genre),
              // Fără checkmark: avatarul de check lărgește chip-ul selectat,
              // ceea ce schimbă lățimea totală a rândului și face Wrap-ul să
              // rearanjeze tot ce urmează după el. Culoarea rămâne singurul
              // semnal de selecție, iar chip-urile nu-și mai schimbă poziția.
              showCheckmark: false,
              onSelected: (selected) => setState(() {
                if (selected) {
                  _selectedGenres.add(genre);
                } else {
                  _selectedGenres.remove(genre);
                }
              }),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Text(context.l10n.surveyGenresLoadError),
    );
  }

  Widget _buildFrequencyContent() {
    final l10n = context.l10n;
    final options = [
      (_kReadingPaces[0], l10n.onboardingFlowFrequencyLowTitle, l10n.onboardingFlowFrequencyLowDesc, Icons.menu_book_outlined),
      (_kReadingPaces[1], l10n.onboardingFlowFrequencyMidTitle, l10n.onboardingFlowFrequencyMidDesc, Icons.auto_stories_outlined),
      (_kReadingPaces[2], l10n.onboardingFlowFrequencyHighTitle, l10n.onboardingFlowFrequencyHighDesc, Icons.local_library_outlined),
    ];
    return Column(
      children: [
        for (final option in options) ...[
          _OptionCard(
            icon: option.$4,
            title: option.$2,
            subtitle: option.$3,
            selected: _readingPace == option.$1,
            onTap: () => setState(() => _readingPace = option.$1),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildLocationContent() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CityAutocomplete(
          value: _city,
          label: l10n.profileCityLabel,
          emptyLabel: l10n.shareCityUnknown,
          onChanged: (city) => setState(() => _city = city),
        ),
        const SizedBox(height: 24),
        Text(l10n.onboardingFlowLanguagesLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final lang in _kLanguagePreset)
              FilterChip(
                label: Text(lang),
                selected: _selectedLanguages.contains(lang),
                showCheckmark: false,
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedLanguages.add(lang);
                  } else {
                    _selectedLanguages.remove(lang);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPurposeContent() {
    final l10n = context.l10n;
    final options = [
      (_kPurposes[0], l10n.onboardingFlowPurposeSwapTitle, l10n.onboardingFlowPurposeSwapDesc, Icons.swap_horiz),
      (_kPurposes[1], l10n.onboardingFlowPurposeSellTitle, l10n.onboardingFlowPurposeSellDesc, Icons.sell_outlined),
      (_kPurposes[2], l10n.onboardingFlowPurposeDiscoverTitle, l10n.onboardingFlowPurposeDiscoverDesc, Icons.explore_outlined),
      (_kPurposes[3], l10n.onboardingFlowPurposeAllTitle, l10n.onboardingFlowPurposeAllDesc, Icons.done_all),
    ];
    return Column(
      children: [
        for (final option in options) ...[
          _OptionCard(
            icon: option.$4,
            title: option.$2,
            subtitle: option.$3,
            selected: _purpose == option.$1,
            onTap: () => setState(() => _purpose = option.$1),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _openAddBook() async {
    // Navigator imperativ, nu context.push: un push prin GoRouter ar
    // schimba state.matchedLocation, iar redirect-ul global (care
    // forțează /onboarding cât timp readingSurveyCompletedAt e null)
    // ne-ar trimite instant înapoi - un "loop" din care se ieșea doar
    // cu Skip. Așa, AddBookScreen se deschide peste ecranul curent
    // fără ca GoRouter să considere că am părăsit /onboarding.
    final added = await Navigator.of(context, rootNavigator: true).push<Object>(
      MaterialPageRoute<Object>(builder: (_) => const AddBookScreen()),
    );
    if (!mounted) return;
    // Listarea întoarce UserBook (are și pozele proprii), „add to shelf"
    // întoarce direct cartea din catalog.
    if (added is UserBook) {
      setState(() {
        _addedBook = added.book;
        _addedBookImageUrl = added.primaryImageUrl;
      });
    } else if (added is Book) {
      setState(() {
        _addedBook = added;
        _addedBookImageUrl = added.coverUrl;
      });
    }
  }

  Widget _buildAddBooksContent() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cartea abia adăugată ia locul cardului CTA (nu stă deasupra lui) -
        // altfel userul revine din AddBookScreen și tot vede doar "+ Add a
        // book", ca și cum n-ar fi ținut minte ce a adăugat.
        _addedBook != null ? _buildAddedBookCard() : _buildAddBookCta(),
        const SizedBox(height: 14),
        Text(
          l10n.onboardingFlowAddBooksSkipNote,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.mutedForeground, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // Aceeași structură ca [_buildAddBookCta] (poza/iconița din stânga, titlu +
  // subtitlu în dreapta) dar populată cu cartea abia adăugată: coperta
  // (după ISBN, prin BookCover) ia locul iconiței de căutare, titlul cărții
  // ia locul „Add a book", iar autor+an iau locul textului de ajutor.
  Widget _buildAddedBookCard() {
    final l10n = context.l10n;
    final book = _addedBook!;
    final subtitle = [
      if (book.author != null && book.author!.isNotEmpty) book.author!,
      if (book.publishedYear != null) '${book.publishedYear}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.primary),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 62,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BookCover.expand(
                      url: _addedBookImageUrl,
                      title: book.title,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _openAddBook,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.onboardingFlowAddBooksCta),
        ),
      ],
    );
  }

  Widget _buildAddBookCta() {
    final l10n = context.l10n;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openAddBook,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.search, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.onboardingFlowAddBooksCta,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      l10n.onboardingFlowAddBooksCtaSubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pasul 0: nume + username, obligatoriu (fără Skip/Back - e primul pas și
/// username-ul e cerut oriunde altundeva în aplicație, vezi user.username
/// @unique). Formular separat de restul wizard-ului fiindcă are propria
/// validare și propriul buton de submit (nu Continue/Skip generice).
class _Step0Username extends StatelessWidget {
  const _Step0Username({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.usernameController,
    required this.nameVisible,
    required this.onNameVisibleChanged,
    required this.saving,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController usernameController;
  final bool nameVisible;
  final ValueChanged<bool> onNameVisibleChanged;
  final bool saving;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.onboardingTitle, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          textAlignVertical: TextAlignVertical.center,
                          controller: firstNameController,
                          decoration: InputDecoration(
                            hintText: l10n.onboardingFirstName,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? l10n.commonRequired : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          textAlignVertical: TextAlignVertical.center,
                          controller: lastNameController,
                          decoration: InputDecoration(
                            hintText: l10n.onboardingLastName,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? l10n.commonRequired : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          textAlignVertical: TextAlignVertical.center,
                          controller: usernameController,
                          decoration: InputDecoration(
                            hintText: l10n.onboardingUsername,
                            prefixIcon: const Icon(Icons.alternate_email),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return l10n.commonRequired;
                            if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value.trim())) {
                              return l10n.onboardingUsernameFormatError;
                            }
                            return null;
                          },
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.onboardingNameVisibleSwitch),
                          subtitle: Text(l10n.onboardingUsernameAlwaysVisible),
                          value: nameVisible,
                          onChanged: onNameVisibleChanged,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: saving ? null : onSubmit,
                          child: saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryForeground,
                                  ),
                                )
                              : Text(l10n.commonContinue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pasul -1: panel de bun venit, doar informativ (fără Skip/Back, la fel ca
/// pasul 0 - e primul lucru pe care userul îl vede, n-are ce să sară sau la
/// ce să se întoarcă). Reia exact structura vizuală a [_Step0Username]
/// (Center → SingleChildScrollView → ConstrainedBox 420 → Card) în loc să
/// inventeze un alt layout de slide.
class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.onContinue});
  final VoidCallback onContinue;

  static final Uri _sourceUri =
      Uri.parse('https://ribble-pack.co.uk/blog/much-paper-comes-one-tree');

  Future<void> _openSource() => launchUrl(_sourceUri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BookshelfIllustration(),
              const SizedBox(height: 16),
              Text(
                l10n.onboardingWelcomeTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, bullet) in [
                        l10n.onboardingWelcomeBullet1,
                        l10n.onboardingWelcomeBullet2,
                        l10n.onboardingWelcomeBullet3,
                        l10n.onboardingWelcomeBullet4,
                      ].indexed)
                        Padding(
                          padding: EdgeInsets.only(bottom: index == 3 ? 0 : 16),
                          child: Text(bullet, style: Theme.of(context).textTheme.bodyLarge),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openSource,
                child: Text(
                  l10n.onboardingWelcomeSource,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue,
                  child: Text(l10n.commonContinue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de opțiune tip "tile" (iconiță + checkbox), pentru întrebările cu
/// răspuns unic (frecvență, scop) - semantica rămâne single-select (un
/// singur card selectat per grup), doar indicatorul vizual e un checkbox,
/// nu un Radio.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                _OptionIconTile(icon: icon!, selected: selected),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SelectionCheckbox(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Iconița din stânga fiecărui [_OptionCard], într-un pătrat rotunjit -
/// preia stilul "tile" cerut de user, colorat cu tema aplicației (nu
/// culorile din mockup-ul de referință).
class _OptionIconTile extends StatelessWidget {
  const _OptionIconTile({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: selected ? AppColors.primaryForeground : AppColors.mutedForeground,
      ),
    );
  }
}

/// Indicator de selecție în stil checkbox (pătrat, nu cerc) - vizual mai
/// prietenos decât [Radio], deși semantica rămâne single-select (whole-tile
/// tap, un singur `_OptionCard` selectat per grup de opțiuni).
class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.5),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: AppColors.primaryForeground)
          : null,
    );
  }
}
