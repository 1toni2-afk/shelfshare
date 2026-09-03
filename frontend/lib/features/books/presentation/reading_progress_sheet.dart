import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../shared/widgets/field_label.dart';
import '../data/bookshelf_repository.dart';
import '../data/reading_progress_repository.dart';
import 'review_sheet.dart';

/// Formularul de progres la citit pentru o carte deținută (My Shelf).
///
/// Două lucruri pe care dialogul vechi de pe „Public Bookshelf" nu le avea:
/// - progresul se poate da în PAGINI sau în PROCENTE (mulți useri știu doar
///   „sunt pe la jumate"); procentul e convertit în pagini la salvare, ca
///   sursa de adevăr să rămână `ReadingProgress.currentPage`;
/// - numărul TOTAL de pagini e editabil - ediția din mâna userului poate să
///   difere de cea din catalog, iar fără asta bara de progres mințea.
///
/// Întoarce `true` dacă s-a salvat ceva (apelantul invalidează providerele).
/// Ce s-a intamplat in sheet. `justFinished` e true DOAR la trecerea in
/// „citita" - nu si cand cartea era deja terminata si userul doar reeditat
/// progresul, ca promptul de recenzie sa nu reapara la fiecare salvare.
class _SheetResult {
  const _SheetResult({required this.saved, required this.justFinished});
  final bool saved;
  final bool justFinished;
}

Future<bool> showReadingProgressSheet(
  BuildContext context,
  WidgetRef ref, {
  required Book book,
  required int currentPage,
  int? totalPages,
}) async {
  final result = await showModalBottomSheet<_SheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReadingProgressSheet(
      book: book,
      currentPage: currentPage,
      totalPages: totalPages ?? book.pageCount,
    ),
  );
  if (result == null) return false;

  // Promptul de recenzie e SOFT: o intrebare, cu „nu acum" ca iesire evidenta.
  // Momentul in care userul tocmai a terminat cartea e singurul in care are
  // ceva de spus despre ea si e inca proaspat - dar a-i cere obligatoriu o
  // recenzie ca sa poata marca o carte drept citita ar strica exact fluxul
  // pe care il masuram (progresul la citit).
  if (result.justFinished && context.mounted) {
    await _promptForReview(context, ref, book);
  }
  return result.saved;
}

Future<void> _promptForReview(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  final l10n = context.l10n;
  final wantsToReview = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.reviewPromptTitle),
      content: Text(l10n.reviewPromptBody(book.title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.reviewPromptNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.reviewPromptWrite),
        ),
      ],
    ),
  );
  if (wantsToReview != true || !context.mounted) return;
  await showReviewSheet(context, ref, book: book);
}

enum _ProgressUnit { pages, percent }

class _ReadingProgressSheet extends ConsumerStatefulWidget {
  const _ReadingProgressSheet({
    required this.book,
    required this.currentPage,
    this.totalPages,
  });

  final Book book;
  final int currentPage;
  final int? totalPages;

  /// Cartea era DEJA terminata cand s-a deschis sheet-ul.
  bool get wasFinished => totalPages != null && currentPage >= totalPages!;

  @override
  ConsumerState<_ReadingProgressSheet> createState() => _ReadingProgressSheetState();
}

class _ReadingProgressSheetState extends ConsumerState<_ReadingProgressSheet> {
  late final TextEditingController _totalController;
  late final TextEditingController _valueController;
  _ProgressUnit _unit = _ProgressUnit.pages;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController(text: widget.totalPages?.toString() ?? '');
    _valueController = TextEditingController(
      text: widget.currentPage > 0 ? widget.currentPage.toString() : '',
    );
    _totalController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _totalController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  int? get _total {
    final n = int.tryParse(_totalController.text.trim());
    return n != null && n > 0 ? n : null;
  }

  /// Comutarea pagini <-> procent păstrează valoarea deja introdusă, convertind-o
  /// - altfel userul care apasă din greșeală pe „Procent" își pierde cifra.
  void _switchUnit(_ProgressUnit unit) {
    if (unit == _unit) return;
    final total = _total;
    final value = int.tryParse(_valueController.text.trim());
    if (unit == _ProgressUnit.percent && total == null) {
      setState(() => _error = context.l10n.shelfProgressNeedTotal);
      return;
    }
    if (value != null && total != null && total > 0) {
      _valueController.text = unit == _ProgressUnit.percent
          ? ((value / total) * 100).round().clamp(0, 100).toString()
          : ((value / 100) * total).round().clamp(0, total).toString();
    }
    setState(() {
      _unit = unit;
      _error = null;
    });
  }

  Future<void> _save({bool finished = false}) async {
    final l10n = context.l10n;
    final total = _total;
    int page;

    if (finished) {
      if (total == null) {
        setState(() => _error = l10n.shelfProgressNeedTotal);
        return;
      }
      page = total;
    } else {
      final value = int.tryParse(_valueController.text.trim());
      if (value == null) {
        setState(() => _error = l10n.bookshelfProgressError);
        return;
      }
      if (_unit == _ProgressUnit.percent) {
        if (total == null) {
          setState(() => _error = l10n.shelfProgressNeedTotal);
          return;
        }
        page = ((value.clamp(0, 100) / 100) * total).round();
      } else {
        page = value;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(readingProgressRepositoryProvider)
          .setProgress(widget.book.id, page, totalPages: total);
      // Statusul de raft urmează progresul: cine ajunge la ultima pagină e
      // „Finished", cine e la mijloc e „Reading". Fără asta, cartea rămânea
      // „Reading" la infinit și butonul de listare nu apărea niciodată.
      final isDone = total != null && page >= total;
      await ref.read(bookshelfRepositoryProvider).setStatus(
            widget.book.id,
            isDone ? BookshelfStatus.finished : BookshelfStatus.reading,
            owned: true,
          );
      ref.invalidate(myReadingProgressProvider);
      ref.invalidate(myOwnedShelfProvider);
      ref.invalidate(myBookshelfProvider);
      if (mounted) {
        Navigator.of(context).pop(
          _SheetResult(saved: true, justFinished: isDone && !widget.wasFinished),
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
          : l10n.bookshelfProgressError;
      if (mounted) {
        setState(() {
          _saving = false;
          _error = message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.bookshelfProgressError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      // Ridicăm conținutul peste tastatură - câmpurile sunt numerice, dar pe
      // mobil tastatura acoperea altfel butonul de salvare.
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.book.title, style: theme.textTheme.titleMedium),
            if (widget.book.author != null)
              Text(
                widget.book.author!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              ),
            const SizedBox(height: 16),
            FieldLabel(l10n.shelfProgressTotalPages),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: _totalController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(hintText: l10n.shelfProgressTotalPages),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_ProgressUnit>(
              segments: [
                ButtonSegment(value: _ProgressUnit.pages, label: Text(l10n.shelfProgressUnitPages)),
                ButtonSegment(value: _ProgressUnit.percent, label: Text(l10n.shelfProgressUnitPercent)),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => _switchUnit(s.first),
            ),
            const SizedBox(height: 12),
            FieldLabel(_unit == _ProgressUnit.pages
                ? l10n.shelfProgressPagesRead
                : l10n.shelfProgressPercentRead),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: _valueController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: _unit == _ProgressUnit.pages
                    ? l10n.shelfProgressPagesRead
                    : l10n.shelfProgressPercentRead,
                suffixText: _unit == _ProgressUnit.percent ? '%' : null,
                helperText: _unit == _ProgressUnit.pages && _total != null
                    ? l10n.bookshelfProgressFieldOfTotal(_total!)
                    : null,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(finished: true),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(l10n.shelfProgressMarkFinished, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.commonSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
