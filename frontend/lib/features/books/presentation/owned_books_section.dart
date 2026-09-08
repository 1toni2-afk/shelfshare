import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../shared/widgets/book_cover.dart';
import '../application/my_library_controller.dart';
import '../data/bookshelf_repository.dart';
import '../data/reading_progress_repository.dart';
import 'reading_progress_sheet.dart';
import 'relist_book_sheet.dart';

/// Prim-planul din My Shelf: cărțile pe care userul le DEȚINE dar nu le-a scos
/// la listare. Sunt majoritatea rafturilor reale - cineva are acasă zeci de
/// cărți și dă mai departe câteva - deci stau deasupra anunțurilor, nu sub ele.
///
/// Fiecare rând e o intrare de progres la citit; când cartea e terminată,
/// primește butonul care duce la listare, cu datele deja completate.
class OwnedBooksSection extends ConsumerWidget {
  const OwnedBooksSection({super.key});

  /// Deschide „adaugă carte" direct pe modul de listare, cu titlul/autorul
  /// cărții terminate precompletate - vezi ruta /library/add.
  static void listBook(BuildContext context, Book book) {
    final params = <String, String>{
      'mode': 'listing',
      'bookId': book.id,
      'title': book.title,
      if (book.author != null) 'author': book.author!,
      if (book.isbn != null) 'isbn': book.isbn!,
      if (book.coverUrl != null) 'cover': book.coverUrl!,
    };
    context.push(Uri(path: '/library/add', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(myOwnedShelfProvider);

    // Erorile nu blochează ecranul: listările de dedesubt sunt utile și fără
    // secțiunea asta, deci pe eroare/încărcare pur și simplu nu ocupăm loc.
    final books = async.value;
    if (books == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.shelfOwnedSectionTitle, style: theme.textTheme.titleMedium),
                  Text(
                    l10n.shelfOwnedSectionSubtitle(books.length),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/library/add'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.shelfOwnedAddCta),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (books.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.shelfOwnedEmpty,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedForeground),
              ),
            ),
          )
        else
          for (final owned in books)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OwnedBookTile(owned: owned),
            ),
      ],
    );
  }
}

class _OwnedBookTile extends ConsumerWidget {
  const _OwnedBookTile({required this.owned});
  final OwnedBook owned;

  Future<void> _editProgress(BuildContext context, WidgetRef ref) async {
    await showReadingProgressSheet(
      context,
      ref,
      book: owned.book,
      currentPage: owned.currentPage,
      totalPages: owned.totalPages,
    );
  }

  /// Listarea dintr-un singur click, direct din „Cărțile mele".
  ///
  /// Cartea primită printr-un schimb are deja un exemplar al userului, doar
  /// nescos în piață - pe aceea o re-listăm (foaia de re-listare), altfel am
  /// crea un al doilea rând pentru aceeași carte. Restul merg pe fluxul
  /// normal de listare, cu datele precompletate.
  Future<void> _listNow(BuildContext context, WidgetRef ref) async {
    final relistSourceId = owned.relistSourceId;
    if (relistSourceId == null) {
      OwnedBooksSection.listBook(context, owned.book);
      return;
    }
    await showRelistBookSheet(
      context,
      originalUserBookId: relistSourceId,
      bookTitle: owned.book.title,
    );
    ref.invalidate(myOwnedShelfProvider);
    ref.invalidate(myLibraryControllerProvider);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    await ref.read(bookshelfRepositoryProvider).removeFromShelf(owned.book.id);
    ref.invalidate(myOwnedShelfProvider);
    ref.invalidate(myBookshelfProvider);
    ref.invalidate(myReadingProgressProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final fraction = owned.progress;
    final total = owned.totalPages;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editProgress(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(url: owned.book.coverUrl, width: 44, height: 62),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                owned.book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            if (owned.listed) ...[
                              const SizedBox(width: 6),
                              _ListedBadge(label: l10n.shelfOwnedListedBadge),
                            ],
                          ],
                        ),
                        if (owned.book.author != null)
                          Text(
                            owned.book.author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                        const SizedBox(height: 8),
                        if (fraction != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: fraction, minHeight: 5),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          total != null
                              ? '${l10n.bookshelfProgressLabel(owned.currentPage, total)} · '
                                  '${l10n.shelfProgressPercentLabel(((fraction ?? 0) * 100).round())}'
                              : l10n.bookshelfProgressLabelNoTotal(owned.currentPage),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  // Listarea e acțiunea cea mai cerută de aici, deci stă la
                  // vedere, la un singur click - nu ascunsă în meniu.
                  if (!owned.listed)
                    IconButton(
                      icon: const Icon(Icons.storefront_outlined),
                      tooltip: l10n.shelfListItNow,
                      onPressed: () => _listNow(context, ref),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'progress':
                          _editProgress(context, ref);
                        case 'about':
                          context.push('/work/${owned.book.id}');
                        case 'list':
                          _listNow(context, ref);
                        case 'remove':
                          _remove(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'progress', child: Text(l10n.shelfUpdateProgress)),
                      PopupMenuItem(value: 'about', child: Text(l10n.workTitle)),
                      // Deja listată: nu-i mai propunem s-o listeze încă o dată.
                      if (!owned.listed)
                        PopupMenuItem(value: 'list', child: Text(l10n.shelfListItNow)),
                      PopupMenuItem(value: 'remove', child: Text(l10n.shelfRemoveFromShelf)),
                    ],
                  ),
                ],
              ),
              // Cartea terminată e singurul moment în care propunerea de a o da
              // mai departe e la locul ei - până atunci userul încă o citește.
              if (owned.isFinished && !owned.listed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.shelfFinishedCta,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _listNow(context, ref),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: Text(l10n.shelfListItNow),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Eticheta „Listată" de pe o carte care e și în curs de citire, și scoasă la
/// schimb - apare în ambele locuri din My Shelf, deci merită spus care e care.
class _ListedBadge extends StatelessWidget {
  const _ListedBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}
