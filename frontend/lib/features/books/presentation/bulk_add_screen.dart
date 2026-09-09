import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/external_book_result.dart';
import '../../../data/models/store.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/application/admin_stores_controller.dart';
import '../application/my_library_controller.dart';
import '../data/books_repository.dart';

class _QueuedIsbn {
  _QueuedIsbn(this.isbn) : preview = null, isLoading = true;
  final String isbn;
  ExternalBookResult? preview;
  bool isLoading;
}

/// Adăugarea în masă - unealta de operare pentru integrările cu anticariatele,
/// rezervată super-adminilor (vezi SuperAdminGuard pe POST /books/bulk și
/// redirectul din app_router.dart).
///
/// Două căi, aceeași țintă aleasă o singură dată sus:
///   * scanare/lipire de ISBN-uri, pentru un raft mic luat pe loc;
///   * import CSV cu preț și stoc, pentru un feed întreg. Rândul cu un `sku`
///     deja trimis actualizează anunțul existent, deci fișierul poate fi
///     re-trimis zilnic fără să dubleze nimic.
///
/// Ținta poate fi contul propriu sau un cont de magazin: cărțile unui
/// anticariat trebuie să ajungă la anticariat, nu pe raftul personal al celui
/// care ține telefonul.
class BulkAddScreen extends ConsumerStatefulWidget {
  const BulkAddScreen({super.key});

  @override
  ConsumerState<BulkAddScreen> createState() => _BulkAddScreenState();
}

class _BulkAddScreenState extends ConsumerState<BulkAddScreen>
    with SingleTickerProviderStateMixin {
  final List<_QueuedIsbn> _queue = [];
  final _manualController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  bool _showScanner = false;
  BookCondition _condition = BookCondition.buna;
  bool _isSubmitting = false;
  BulkAddResult? _result;

  /// `null` = contul propriu. Altfel, userId-ul magazinului țintă.
  String? _storeUserId;

  ListingImportResult? _importResult;
  String? _importError;
  bool _isImporting = false;

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _addIsbn(String rawIsbn) async {
    final isbn = rawIsbn.replaceAll(RegExp(r'[-\s]'), '').trim();
    if (isbn.isEmpty || _queue.any((q) => q.isbn == isbn)) return;

    final entry = _QueuedIsbn(isbn);
    setState(() => _queue.add(entry));
    try {
      final preview = await ref.read(booksRepositoryProvider).lookupIsbn(isbn);
      if (mounted) {
        setState(() {
          entry.preview = preview;
          entry.isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => entry.isLoading = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null) _addIsbn(value);
    }
  }

  void _addManualIsbns() {
    final lines = _manualController.text.split(RegExp(r'[\n,]'));
    for (final line in lines) {
      _addIsbn(line);
    }
    _manualController.clear();
  }

  void _removeIsbn(String isbn) {
    setState(() => _queue.removeWhere((q) => q.isbn == isbn));
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(booksRepositoryProvider).bulkAdd(
            _queue.map((q) => q.isbn).toList(),
            condition: _condition,
            storeUserId: _storeUserId,
          );
      // Doar când cărțile au ajuns pe raftul propriu are ce reîncărca.
      if (_storeUserId == null) ref.invalidate(myLibraryControllerProvider);
      if (mounted) setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _importCsv() async {
    final l10n = context.l10n;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file?.bytes == null || !mounted) return;

    setState(() {
      _isImporting = true;
      _importError = null;
      _importResult = null;
    });
    try {
      final result = await ref.read(booksRepositoryProvider).importListingsCsv(
            bytes: file!.bytes!,
            filename: file.name,
            storeUserId: _storeUserId,
          );
      if (_storeUserId == null) ref.invalidate(myLibraryControllerProvider);
      if (mounted) setState(() => _importResult = result);
    } on DioException catch (e) {
      // Mesajul serverului spune exact ce n-a mers (rânduri prea multe, CSV
      // nevalid, magazin suspendat) - mai util decât un text generic.
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List
              ? (data['message'] as List).join(', ')
              : data['message'].toString())
          : l10n.libraryImportError;
      if (mounted) setState(() => _importError = message);
    } catch (_) {
      if (mounted) setState(() => _importError = l10n.libraryImportError);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_result != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.bulkAddTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.bulkAddResultSummary(_result!.created.length, _result!.failed.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (final created in _result!.created)
                ListTile(
                  leading: Icon(Icons.check_circle_outline, color: AppColors.success),
                  title: Text(created.title),
                ),
              for (final failed in _result!.failed)
                ListTile(
                  leading: Icon(Icons.error_outline, color: AppColors.destructive),
                  title: Text(failed.isbn),
                  subtitle: Text(failed.reason),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonDone),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bulkAddTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.bulkAddTabScan),
            Tab(text: l10n.bulkAddTabCsv),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StoreTargetPicker(
              selected: _storeUserId,
              onChanged: (value) => setState(() => _storeUserId = value),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [_buildScanTab(l10n), _buildCsvTab(l10n)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanTab(AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _showScanner ? l10n.bulkAddScanTooltip : l10n.bulkAddManualEntry,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                icon: Icon(_showScanner ? Icons.keyboard : Icons.qr_code_scanner),
                tooltip: _showScanner ? l10n.bulkAddManualEntry : l10n.bulkAddScanTooltip,
                onPressed: () => setState(() => _showScanner = !_showScanner),
              ),
            ],
          ),
        ),
        if (_showScanner)
          SizedBox(
            height: 260,
            child: MobileScanner(controller: _scannerController, onDetect: _onDetect),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.bulkAddManualHint, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualController,
                  maxLines: 4,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(hintText: l10n.bulkAddManualPlaceholder),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _addManualIsbns, child: Text(l10n.bulkAddAddIsbns)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<BookCondition>(
            initialValue: _condition,
            decoration: InputDecoration(labelText: l10n.filtersCondition),
            items: [
              for (final condition in BookCondition.values)
                DropdownMenuItem(value: condition, child: Text(condition.label(l10n))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _condition = value);
            },
          ),
        ),
        Expanded(
          child: _queue.isEmpty
              ? Center(child: Text(l10n.bulkAddQueueEmpty))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _queue.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _queue[index];
                    return ListTile(
                      leading: entry.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              entry.preview != null ? Icons.book_outlined : Icons.help_outline,
                              color: entry.preview == null ? AppColors.mutedForeground : null,
                            ),
                      title: Text(entry.preview?.title ?? entry.isbn),
                      subtitle: entry.preview?.author != null
                          ? Text(entry.preview!.author!,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeIsbn(entry.isbn),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _queue.isEmpty || _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.bulkAddSubmit(_queue.length)),
          ),
        ),
      ],
    );
  }

  Widget _buildCsvTab(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final result = _importResult;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.bulkAddCsvHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        // Prețul din CSV pune anunțul la vânzare doar pentru un cont de
        // magazin - pe contul propriu rămâne regula „cel puțin o poză".
        if (_storeUserId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.bulkAddCsvNoStore,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
        FilledButton.icon(
          onPressed: _isImporting ? null : _importCsv,
          icon: _isImporting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file_outlined),
          label: Text(l10n.bulkAddCsvPick),
        ),
        if (_importError != null) ...[
          const SizedBox(height: 12),
          Text(
            _importError!,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.destructive),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: 20),
          Text(
            l10n.libraryImportSummaryDetailed(
              result.created.length,
              result.updated.length,
              result.delisted.length,
              result.failed.length,
            ),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          for (final failed in result.failed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.error_outline, color: AppColors.destructive),
              title: Text(failed.title),
              subtitle: Text(failed.reason),
            ),
        ],
      ],
    );
  }
}

/// Contul în care intră cărțile: al meu, sau un anticariat.
///
/// Lista de magazine vine de pe ruta de super-admin - același drept cerut de
/// ecranul ăsta, deci nu e o cerere în plus pentru nimeni. Magazinele
/// suspendate nu apar: backendul le-ar refuza oricum stocul.
class _StoreTargetPicker extends ConsumerWidget {
  const _StoreTargetPicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stores = ref.watch(adminStoresControllerProvider).value ?? const <StoreAccount>[];
    final active = stores.where((s) => s.isActive).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: DropdownButtonFormField<String?>(
        initialValue: selected,
        decoration: InputDecoration(labelText: l10n.bulkAddTarget),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(l10n.bulkAddTargetOwn)),
          for (final store in active)
            DropdownMenuItem<String?>(
              value: store.userId,
              child: Text(store.profile.displayName, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
