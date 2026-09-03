import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../data/reviews_repository.dart';

/// Formularul de recenzie: steluțe + text opțional.
///
/// Se deschide din pagina operei („scrie o recenzie") și din promptul soft de
/// după marcarea unei cărți drept citită. Textul e opțional în ambele cazuri -
/// nota singură e deja utilă, iar a cere un paragraf ar face ca cei mai mulți
/// să nu lase nimic.
///
/// Întoarce `true` dacă recenzia a fost salvată, `null` dacă userul a închis
/// fereastra - apelantul reîmprospătează pagina doar în primul caz.
Future<bool?> showReviewSheet(
  BuildContext context,
  WidgetRef ref, {
  required Book book,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _ReviewSheet(book: book),
    ),
  );
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.book});
  final Book book;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _textController = TextEditingController();
  int _rating = 0;
  bool _saving = false;
  bool _loadingExisting = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  /// O recenzie existentă se EDITEAZĂ, nu se dublează (`POST /reviews` e un
  /// upsert pe user+carte). Fără pasul ăsta, userul care redeschide formularul
  /// ar porni de la zero și și-ar suprascrie propriul text fără să vadă.
  Future<void> _loadExisting() async {
    try {
      final mine = await ref.read(reviewsRepositoryProvider).getMine(widget.book.id);
      if (!mounted) return;
      setState(() {
        if (mine != null) {
          _rating = mine.rating;
          _textController.text = mine.text ?? '';
        }
        _loadingExisting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.reviewNeedRating)));
      return;
    }
    setState(() => _saving = true);
    try {
      final text = _textController.text.trim();
      await ref
          .read(reviewsRepositoryProvider)
          .upsert(widget.book.id, _rating, text.isEmpty ? null : text);
      ref.invalidate(bookReviewsProvider(widget.book.id));
      ref.invalidate(myReviewProvider(widget.book.id));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.commonGenericError)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reviewSheetTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.book.title,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            if (_loadingExisting)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ))
            else ...[
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        onPressed: () => setState(() => _rating = star),
                        icon: Icon(
                          _rating >= star ? Icons.star : Icons.star_border,
                          size: 32,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                maxLines: 4,
                maxLength: 2000,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: l10n.reviewTextHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.reviewSave),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
