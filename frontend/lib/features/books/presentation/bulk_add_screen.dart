import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/external_book_result.dart';
import '../application/my_library_controller.dart';
import '../data/books_repository.dart';

class _QueuedIsbn {
  _QueuedIsbn(this.isbn) : preview = null, isLoading = true;
  final String isbn;
  ExternalBookResult? preview;
  bool isLoading;
}

/// "Bulk ISBN Scan" + "Bulk Listing" (Milestone 5) - scanează mai multe
/// coduri de bare (camera, via mobile_scanner) sau lipește mai multe ISBN-uri
/// deodată, apoi le adaugă pe toate în bibliotecă cu o singură stare comună
/// (editarea individuală rămâne posibilă după, prin Edit Listing existent).
class BulkAddScreen extends ConsumerStatefulWidget {
  const BulkAddScreen({super.key});

  @override
  ConsumerState<BulkAddScreen> createState() => _BulkAddScreenState();
}

class _BulkAddScreenState extends ConsumerState<BulkAddScreen> {
  final List<_QueuedIsbn> _queue = [];
  final _manualController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _showScanner = false;
  BookCondition _condition = BookCondition.buna;
  bool _isSubmitting = false;
  BulkAddResult? _result;

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController.dispose();
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
          );
      ref.invalidate(myLibraryControllerProvider);
      if (mounted) setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text(created.title),
                ),
              for (final failed in _result!.failed)
                ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
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
        actions: [
          IconButton(
            icon: Icon(_showScanner ? Icons.keyboard : Icons.qr_code_scanner),
            tooltip: _showScanner ? l10n.bulkAddManualEntry : l10n.bulkAddScanTooltip,
            onPressed: () => setState(() => _showScanner = !_showScanner),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                    DropdownMenuItem(value: condition, child: Text(condition.label)),
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
                          subtitle: entry.preview?.author != null ? Text(entry.preview!.author!) : null,
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
        ),
      ),
    );
  }
}
