import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../application/profile_controller.dart';
import '../data/profile_repository.dart';

/// Genurile propuse vin de la backend, ca lista să nu fie duplicată local.
final _surveyGenresProvider = FutureProvider<List<String>>((ref) {
  return ref.read(profileRepositoryProvider).getSurveyGenres();
});

/// Chestionarul de profil de cititor, arătat o singură dată după primul login
/// (vezi redirect-ul din app_router.dart). Răspunsurile alimentează
/// recomandările și notificarea „carte nouă pe gustul tău".
///
/// Se poate sări peste: un chestionar obligatoriu la prima deschidere e cel mai
/// bun mod de a pierde un user nou. „Sar peste" trimite totuși cererea, ca
/// backend-ul să marcheze chestionarul ca parcurs și să nu îl mai afișeze.
class ReadingSurveyScreen extends ConsumerStatefulWidget {
  const ReadingSurveyScreen({super.key});

  @override
  ConsumerState<ReadingSurveyScreen> createState() => _ReadingSurveyScreenState();
}

class _ReadingSurveyScreenState extends ConsumerState<ReadingSurveyScreen> {
  final _selectedGenres = <String>{};
  final _authorsController = TextEditingController();
  String? _readingPace;
  bool _saving = false;

  static const _paces = ['1', '2-3', '4+'];

  @override
  void dispose() {
    _authorsController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool skip}) async {
    setState(() => _saving = true);
    try {
      await ref.read(profileControllerProvider.notifier).saveReadingSurvey(
            favoriteGenres: skip ? const [] : _selectedGenres.toList(),
            favoriteAuthors: skip ? const [] : _parseAuthors(),
            readingPace: skip ? null : _readingPace,
          );
      // Nu navigăm manual: routerul urmărește authController și, odată ce
      // readingSurveyCompletedAt e setat, redirectează singur spre Home.
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.surveySaveError)));
      }
    }
  }

  /// Autorii se introduc într-un singur câmp, separați prin virgulă - mai puțin
  /// fricțiune decât un câmp per autor la primul contact cu aplicația.
  List<String> _parseAuthors() {
    return _authorsController.text
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .take(20)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final genresAsync = ref.watch(_surveyGenresProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),
                Text(l10n.surveyTitle, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  l10n.surveySubtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 28),

                Text(l10n.surveyGenresQuestion,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                genresAsync.when(
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
                  error: (_, _) => Text(l10n.surveyGenresLoadError),
                ),
                const SizedBox(height: 28),

                Text(l10n.surveyAuthorsQuestion,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _authorsController,
                  decoration: InputDecoration(hintText: l10n.surveyAuthorsHint),
                ),
                const SizedBox(height: 28),

                Text(l10n.surveyPaceQuestion,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final pace in _paces)
                      ChoiceChip(
                        label: Text(l10n.surveyPaceOption(pace)),
                        selected: _readingPace == pace,
                        onSelected: (selected) =>
                            setState(() => _readingPace = selected ? pace : null),
                      ),
                  ],
                ),
                const SizedBox(height: 36),

                ElevatedButton(
                  onPressed: _saving ? null : () => _save(skip: false),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryForeground,
                          ),
                        )
                      : Text(l10n.surveySubmit),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => _save(skip: true),
                  child: Text(l10n.surveySkip),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.surveyChangeLaterHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
