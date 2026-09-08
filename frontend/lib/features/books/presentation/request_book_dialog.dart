import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../application/book_requests_controller.dart';

/// Formularul „nu găsesc cartea", deschis exact acolo unde căutarea a dat gol
/// (vezi add_book_screen.dart). Titlul vine precompletat cu ce tastase omul -
/// dacă îl punem să scrie a doua oară același lucru, nu mai trimite nimeni
/// nimic.
///
/// Ce se întâmplă după trimitere: cererea intră în coada de noapte, unde e
/// căutată cu prioritate în catalogul propriu, la Google Books/Open Library
/// și în librăriile românești (vezi BookRequestsService.resolvePendingRequests
/// și scripts/book-requests/nightly_book_requests.py). Când e găsită, cartea
/// apare în catalog și userul primește notificare.
Future<void> showRequestBookDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialTitle,
  String? initialAuthor,
}) async {
  final l10n = context.l10n;
  final titleController = TextEditingController(text: initialTitle ?? '');
  final authorController = TextEditingController(text: initialAuthor ?? '');
  final noteController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.bookRequestTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bookRequestExplainer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.bookRequestTitleLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: authorController,
              decoration: InputDecoration(hintText: l10n.bookRequestAuthorLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.bookRequestNoteLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.bookRequestSubmit),
        ),
      ],
    ),
  );

  final title = titleController.text.trim();
  final author = authorController.text.trim();
  final note = noteController.text.trim();
  titleController.dispose();
  authorController.dispose();
  noteController.dispose();

  if (confirmed != true || title.isEmpty || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final result =
        await ref.read(bookRequestsControllerProvider.notifier).create(
              title: title,
              author: author.isEmpty ? null : author,
              note: note.isEmpty ? null : note,
            );
    if (!context.mounted) return;

    // Cartea exista deja în catalog (titlul structurat a găsit-o unde textul
    // liber nu reușise) - nu s-a creat nicio cerere, deci nu promitem că „te
    // anunțăm când o găsim", ci ducem omul direct la ea.
    if (result.found && result.bookId != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.bookRequestFoundNow),
          action: SnackBarAction(
            label: l10n.bookRequestOpenBook,
            onPressed: () => context.push('/work/${result.bookId}'),
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.bookRequestSent)));
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.bookRequestError)));
  }
}
