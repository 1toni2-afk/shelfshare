import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/browser_download.dart';
import '../../profile/application/onboarding_todo_controller.dart';
import '../application/my_library_controller.dart';
import '../data/books_repository.dart';
import '../data/import_template.dart';

/// Pagina de import, un singur loc pentru toate fișierele cu cărți: exportul
/// de pe Goodreads sau StoryGraph și șablonul propriu, pentru cine își ține
/// biblioteca într-un fișier de-al lui.
///
/// Până acum importul era un rând într-un meniu „⋮" de pe două ecrane
/// diferite: alegeai fișierul din nimic, fără să afli nicăieri de unde se ia
/// exportul, ce coloane citim sau ce se întâmplă cu fiecare raft. Pașii de
/// aici sunt exact drumul pe care-l face omul (ia fișierul → încarcă-l →
/// pornește importul), iar rezultatul spune pe fiecare categorie unde au
/// ajuns cărțile.
///
/// Toate rândurile trec prin `/books/import-listings` - singura cale care
/// citește rafturile din fișier și trimite fiecare rând unde-i e locul (raft
/// de lectură, favorite sau anunț), în loc să pună tot ce prinde în piață.
class ImportBooksScreen extends ConsumerStatefulWidget {
  const ImportBooksScreen({super.key});

  @override
  ConsumerState<ImportBooksScreen> createState() => _ImportBooksScreenState();
}

class _ImportBooksScreenState extends ConsumerState<ImportBooksScreen> {
  PlatformFile? _file;
  bool _running = false;
  ListingImportResult? _result;
  String? _error;

  Future<void> _openExportPage(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aboutDevOpenError)),
      );
    }
  }

  void _downloadTemplate() {
    downloadTextFile(
      filename: kImportTemplateFilename,
      content: buildImportTemplateCsv(),
      mimeType: 'text/csv',
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file?.bytes == null) return;
    setState(() {
      _file = file;
      // Un fișier nou înseamnă un import nou: rezultatul celui vechi ar rămâne
      // pe ecran lângă butonul de pornire și ar arăta ca și cum s-ar fi
      // întâmplat deja ceva cu fișierul ăsta.
      _result = null;
      _error = null;
    });
  }

  Future<void> _runImport() async {
    final file = _file;
    if (file?.bytes == null || _running) return;
    // Citit înainte de await: după el, contextul poate fi deja demontat.
    final fallbackError = context.l10n.libraryImportError;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(booksRepositoryProvider)
          .importListingsCsv(bytes: file!.bytes!, filename: file.name);
      ref.invalidate(myLibraryControllerProvider);
      // Bifează pasul din „Descoperă ShelfShare" doar dacă a intrat ceva - un fișier
      // gol sau greșit nu e un import făcut.
      if (result.touchedCount + result.shelved.length + result.favorited.length > 0) {
        ref.read(onboardingTodoProvider.notifier).complete(OnboardingTodo.import);
      }
      if (mounted) setState(() => _result = result);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List
              ? (data['message'] as List).join(', ')
              : data['message'].toString())
          : fallbackError;
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(l10n.importTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(l10n.importIntro, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                _step(
                  context,
                  number: 1,
                  title: l10n.importStep1Title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openExportPage(kGoodreadsExportUrl),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(l10n.importStep1Goodreads),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openExportPage(kStoryGraphExportUrl),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(l10n.importStep1StoryGraph),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _hint(context, l10n.importStep1Hint),
                      const Divider(height: 28),
                      OutlinedButton.icon(
                        onPressed: _downloadTemplate,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: Text(l10n.importStep1Template),
                      ),
                      const SizedBox(height: 8),
                      _hint(context, l10n.importStep1TemplateHint),
                    ],
                  ),
                ),
                _step(
                  context,
                  number: 2,
                  title: l10n.importStep2Title,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _running ? null : _pickFile,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: Text(
                          _file == null ? l10n.importStep2Choose : l10n.importStep2Change,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _file?.name ?? l10n.importStep2NoFile,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _file == null ? AppColors.mutedForeground : AppColors.success,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                _step(
                  context,
                  number: 3,
                  title: l10n.importStep3Title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton.icon(
                        onPressed: _file == null || _running ? null : _runImport,
                        icon: _running
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.library_add_outlined, size: 18),
                        label: Text(l10n.importStep3Button),
                      ),
                      if (_running) ...[
                        const SizedBox(height: 8),
                        _hint(context, l10n.importRunning),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  _ErrorBanner(message: _error!),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 4),
                  _ImportResultCard(result: _result!),
                ],
                const SizedBox(height: 8),
                const _GuidelinesCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Un pas numerotat: cerc cu cifra, titlu, conținut. Numerele fac ordinea
  /// evidentă fără să mai scriem „întâi", „apoi" în texte.
  Widget _step(
    BuildContext context, {
    required int number,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.mutedForeground),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.destructive.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.dangerText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.dangerText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rezultatul, pe categorii. Un singur număr („296 importate") nu spune unde
/// au ajuns cărțile, iar în aplicație ele chiar ajung în trei locuri diferite;
/// rândurile sărite și cele eșuate se pot deschide, ca omul să vadă exact ce
/// titluri au rămas pe dinafară.
class _ImportResultCard extends StatelessWidget {
  const _ImportResultCard({required this.result});
  final ListingImportResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nothingHappened = result.touchedCount == 0 &&
        result.shelved.isEmpty &&
        result.favorited.isEmpty &&
        result.skipped.isEmpty &&
        result.failed.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Text(
                  l10n.importResultTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (nothingHappened)
              Text(l10n.importResultEmpty, style: Theme.of(context).textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (result.created.isNotEmpty)
                    _chip(context, Icons.storefront_outlined,
                        l10n.importResultListed(result.created.length), AppColors.accent),
                  if (result.updated.isNotEmpty)
                    _chip(context, Icons.sync_outlined,
                        l10n.importResultUpdated(result.updated.length), AppColors.accent),
                  if (result.shelved.isNotEmpty)
                    _chip(context, Icons.auto_stories_outlined,
                        l10n.importResultShelved(result.shelved.length), AppColors.primary),
                  if (result.favorited.isNotEmpty)
                    _chip(context, Icons.favorite_border,
                        l10n.importResultFavorited(result.favorited.length), AppColors.primary),
                  if (result.skipped.isNotEmpty)
                    _chip(context, Icons.remove_circle_outline,
                        l10n.importResultSkipped(result.skipped.length), AppColors.warning),
                  if (result.failed.isNotEmpty)
                    _chip(context, Icons.error_outline,
                        l10n.importResultFailed(result.failed.length), AppColors.dangerText),
                ],
              ),
            if (result.skipped.isNotEmpty)
              _details(
                context,
                title: l10n.importSkippedTitle,
                rows: [
                  for (final row in result.skipped)
                    (row.title, l10n.importSkippedShelf(row.shelf)),
                ],
              ),
            if (result.failed.isNotEmpty)
              _details(
                context,
                title: l10n.libraryImportFailedTitle(result.failed.length),
                rows: [for (final row in result.failed) (row.title, row.reason)],
              ),
            if (!nothingHappened) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  if (result.shelved.isNotEmpty || result.favorited.isNotEmpty)
                    TextButton(
                      onPressed: () => context.push('/bookshelf'),
                      child: Text(l10n.importGoToShelf),
                    ),
                  if (result.touchedCount > 0)
                    TextButton(
                      onPressed: () => context.go('/library'),
                      child: Text(l10n.importGoToLibrary),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _details(
    BuildContext context, {
    required String title,
    required List<(String, String)> rows,
  }) {
    return Theme(
      // ExpansionTile desenează implicit o linie sus și una jos, care aici,
      // sub șirul de chips, arată ca o margine ruptă a cardului.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        children: [
          for (final (label, detail) in rows)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              subtitle: Text(detail),
            ),
        ],
      ),
    );
  }
}

/// Regulile importului, colapsate: cine vrea doar să încarce un export
/// Goodreads n-are nevoie să le citească, dar cine își scrie fișierul de mână
/// trebuie să le găsească fără să întrebe pe cineva.
class _GuidelinesCard extends StatelessWidget {
  const _GuidelinesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.help_outline, size: 20),
          title: Text(
            l10n.importGuidelinesTitle,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            _bullet(context, l10n.importGuidelineShelfRead),
            _bullet(context, l10n.importGuidelineShelfToRead),
            _bullet(context, l10n.importGuidelineListing),
            _bullet(context, l10n.importGuidelineSkipped),
            _bullet(context, l10n.importGuidelineNoDuplicates),
            const Divider(height: 24),
            _bullet(context, l10n.importGuidelineColumns(kImportCsvColumns.join(', '))),
            _bullet(context, l10n.importGuidelineConditions(kImportConditions.join(', '))),
            _bullet(context, l10n.importGuidelineLimit),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.mutedForeground,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Folosit de ecranele care aveau importul într-un meniu: le lăsăm rândul din
/// meniu, dar duce în pagina asta în loc să deschidă direct file picker-ul.
void openImportPage(BuildContext context) => context.push('/import');
