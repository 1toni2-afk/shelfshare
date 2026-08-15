import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/city_autocomplete.dart';
import '../../book_match/presentation/book_match_screen.dart';
import '../application/profile_controller.dart';
import '../data/profile_repository.dart';

const _kTotalSteps = 7;
const _kReadingPaces = ['1', '2-3', '4+'];
const _kLanguagePreset = ['Română', 'English', 'Magyar', 'Deutsch', 'Français', 'Español', 'Italiano'];
const _kPurposes = ['swap', 'sell', 'discover', 'all'];

final _onboardingGenresProvider = FutureProvider<List<String>>((ref) {
  return ref.read(profileRepositoryProvider).getSurveyGenres();
});

/// Wizard-ul de onboarding, arătat o singură dată la primul login (vezi
/// redirect-ul din app_router.dart). Toți pașii, cu excepția primului
/// (nume + username, obligatoriu - vezi comentariul de pe pasul 0), au Skip
/// și Back. Răspunsurile de la pașii 1-4 stau doar în state local și se
/// salvează o singură dată, la finalul wizard-ului (pasul 6) - așa router-ul
/// nu ne scoate din mijlocul fluxului, iar Back nu are nimic de anulat pe rețea.
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

  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Dacă username-ul e deja setat (ex. userul a închis aplicația la mijlocul
    // wizard-ului și a revenit), pornim direct de la pasul următor.
    final user = ref.read(profileControllerProvider).value;
    _step = user?.username != null ? 1 : 0;
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

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      await ref.read(profileControllerProvider.notifier).updateProfile(
            city: _city,
            languages: _selectedLanguages.toList(),
          );
      await ref.read(profileControllerProvider.notifier).saveReadingSurvey(
            favoriteGenres: _selectedGenres.toList(),
            readingPace: _readingPace,
            purpose: _purpose,
          );
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.surveySaveError)));
      }
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
  }) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 24),
        scrollable ? content : Expanded(child: content),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: scrollable ? SingleChildScrollView(child: body) : body,
              ),
            ),
          ),
        ),
        _buildFooter(isLastStep: isLastStep),
      ],
    );
  }

  Widget _buildFooter({required bool isLastStep}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.onboardingFlowBackTooltip,
                    onPressed: _finishing ? null : _back,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _finishing
                          ? null
                          : () => isLastStep ? _finish() : _next(),
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
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _finishing ? null : () => isLastStep ? _finish() : _next(),
                child: Text(context.l10n.onboardingFlowSkip),
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
              label: Text(genre),
              selected: _selectedGenres.contains(genre),
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
      (_kReadingPaces[0], l10n.onboardingFlowFrequencyLowTitle, l10n.onboardingFlowFrequencyLowDesc),
      (_kReadingPaces[1], l10n.onboardingFlowFrequencyMidTitle, l10n.onboardingFlowFrequencyMidDesc),
      (_kReadingPaces[2], l10n.onboardingFlowFrequencyHighTitle, l10n.onboardingFlowFrequencyHighDesc),
    ];
    return Column(
      children: [
        for (final option in options) ...[
          _OptionCard(
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
      (_kPurposes[0], l10n.onboardingFlowPurposeSwapTitle, l10n.onboardingFlowPurposeSwapDesc),
      (_kPurposes[1], l10n.onboardingFlowPurposeSellTitle, l10n.onboardingFlowPurposeSellDesc),
      (_kPurposes[2], l10n.onboardingFlowPurposeDiscoverTitle, l10n.onboardingFlowPurposeDiscoverDesc),
      (_kPurposes[3], l10n.onboardingFlowPurposeAllTitle, l10n.onboardingFlowPurposeAllDesc),
    ];
    return Column(
      children: [
        for (final option in options) ...[
          _OptionCard(
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

  Widget _buildAddBooksContent() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.border, style: BorderStyle.solid),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/library/add'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.add, color: AppColors.primary),
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
        ),
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
                          controller: firstNameController,
                          decoration: InputDecoration(
                            labelText: l10n.onboardingFirstName,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? l10n.commonRequired : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: lastNameController,
                          decoration: InputDecoration(
                            labelText: l10n.onboardingLastName,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? l10n.commonRequired : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            labelText: l10n.onboardingUsername,
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

/// Card de opțiune cu radio, pentru întrebările cu răspuns unic (frecvență,
/// scop) - vizual apropiat de mockup-ul primit de la user.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
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
              Radio<bool>(
                value: true,
                groupValue: selected ? true : null,
                onChanged: (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
