import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_work.dart';
import '../../../data/models/review.dart';
import '../../../data/models/search_screen_args.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/book_grid_metrics.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/report_reason_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../safety/data/safety_repository.dart';
import '../data/books_repository.dart';
import '../data/bookshelf_repository.dart';
import '../data/reviews_repository.dart';
import 'owned_books_section.dart';
import 'review_sheet.dart';

/// Lățimea de la care pagina trece pe două coloane (copertă lângă text).
const _kWorkWideBreakpoint = 900.0;

/// Pagina „despre carte" - UNA singură per operă, la care duc toate listările
/// din aplicație (Discover, My Shelf, Search, Book Match).
///
/// Distinctă de [BookDetailScreen], care rămâne pagina unui ANUNȚ anume:
/// exemplarul unui user, cu starea, prețul și proprietarul lui. Aici e vorba
/// despre CARTE - ediții, recenzii, cine o are.
///
/// [bookId] e id-ul UNEI ediții; serverul întoarce toată opera în jurul ei
/// (vezi BooksService.getWork), iar dropdown-ul de ediții navighează între
/// ele schimbând ruta - fiecare ediție are propriul URL partajabil.
class BookWorkScreen extends ConsumerWidget {
  const BookWorkScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(bookWorkProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workTitle)),
      body: SafeArea(
        child: async.when(
          loading: () =>
              const CenteredScrollable(child: CircularProgressIndicator()),
          error: (_, _) => CenteredScrollable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.workLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(bookWorkProvider(bookId)),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
          data: (work) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(bookWorkProvider(bookId)),
            child: _WorkBody(work: work),
          ),
        ),
      ),
    );
  }
}

class _WorkBody extends StatelessWidget {
  const _WorkBody({required this.work});
  final BookWork work;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWorkWideBreakpoint;
        final cover = _CoverPanel(book: work.book);
        final header = _HeaderPanel(work: work);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 220, child: cover),
                          const SizedBox(width: 32),
                          Expanded(child: header),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: cover,
                            ),
                          ),
                          const SizedBox(height: 20),
                          header,
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReviewsSection(work: work),
                    const SizedBox(height: 28),
                    _ListingsSection(work: work),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoverPanel extends StatelessWidget {
  const _CoverPanel({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 5 / 7,
      child: BookCover(url: book.coverUrl, title: book.title),
    );
  }
}

/// Titlu, autor, an, dropdown de ediții, rating agregat, descriere și CTA-uri.
class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({required this.work});
  final BookWork work;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final book = work.book;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(book.title, style: theme.textTheme.headlineSmall),
        if (book.author != null) ...[
          const SizedBox(height: 4),
          // Autorul e clicabil și duce în căutare filtrată pe el - la fel ca
          // pe pagina unui anunț, ca gestul să însemne peste tot același lucru.
          InkWell(
            onTap: () => context.push(
              '/browse',
              extra: SearchScreenArgs(author: book.author),
            ),
            child: Text(
              book.author!,
              style:
                  theme.textTheme.titleMedium?.copyWith(color: AppColors.accent),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _MetaLine(book: book),
        if (work.reviews.reviewCount > 0) ...[
          const SizedBox(height: 10),
          _RatingSummary(reviews: work.reviews),
        ],
        if (work.editions.length > 1) ...[
          const SizedBox(height: 16),
          _EditionPicker(work: work),
        ],
        if (book.description != null && book.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.workAbout, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(book.description!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 20),
        _WorkActions(work: work),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = <String>[
      if (book.publishedYear != null) '${book.publishedYear}',
      if (book.publisher != null && book.publisher!.trim().isNotEmpty)
        book.publisher!,
      if (book.pageCount != null) l10n.workPages(book.pageCount!),
      if (book.genre != null && book.genre!.trim().isNotEmpty) book.genre!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.mutedForeground),
    );
  }
}

/// Dropdown-ul de ediții. Schimbarea ediției e o NAVIGARE, nu o schimbare de
/// stare locală: fiecare ediție are propriul URL, iar butonul de back se
/// comportă cum se așteaptă userul.
class _EditionPicker extends StatelessWidget {
  const _EditionPicker({required this.work});
  final BookWork work;

  String _label(BuildContext context, Book edition) {
    final parts = <String>[
      if (edition.publishedYear != null) '${edition.publishedYear}',
      if (edition.publisher != null && edition.publisher!.trim().isNotEmpty)
        edition.publisher!,
      if (edition.language != null && edition.language!.trim().isNotEmpty)
        edition.language!.toUpperCase(),
    ];
    return parts.isEmpty ? context.l10n.workEditionUnnamed : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.workEditions(work.editions.length),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: work.book.id,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            for (final edition in work.editions)
              DropdownMenuItem(
                value: edition.id,
                child: Text(
                  _label(context, edition),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id == null || id == work.book.id) return;
            context.push('/work/$id');
          },
        ),
      ],
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.reviews});
  final BookReviews reviews;

  @override
  Widget build(BuildContext context) {
    final average = reviews.averageRating ?? 0;
    return Row(
      children: [
        StarRating(rating: average),
        const SizedBox(width: 8),
        Text(
          average.toStringAsFixed(1),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Text(
          context.l10n.workRatingCount(reviews.reviewCount),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}

/// Acțiunile principale de pe pagina operei: pune-o pe raft, sau treci la
/// exemplarele listate ca să ceri un schimb.
class _WorkActions extends ConsumerStatefulWidget {
  const _WorkActions({required this.work});
  final BookWork work;

  @override
  ConsumerState<_WorkActions> createState() => _WorkActionsState();
}

class _WorkActionsState extends ConsumerState<_WorkActions> {
  bool _saving = false;

  Future<void> _addToShelf(BookshelfStatus status) async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      // „Vreau s-o citesc" NU înseamnă că o deții - doar „în curs de citire"
      // marchează deținerea, ca raftul din My Shelf să nu se umple cu cărți
      // pe care userul nu le are (vezi BookshelfEntry.owned).
      await ref.read(bookshelfRepositoryProvider).setStatus(
            widget.work.book.id,
            status,
            owned: status != BookshelfStatus.wantToRead,
          );
      ref.invalidate(myOwnedShelfProvider);
      ref.invalidate(myBookshelfProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.workAddedToShelf)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.commonGenericError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listings = widget.work.listings;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _saving ? null : () => _addToShelf(BookshelfStatus.reading),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: Text(l10n.workAddToShelf),
        ),
        OutlinedButton.icon(
          onPressed:
              _saving ? null : () => _addToShelf(BookshelfStatus.wantToRead),
          icon: const Icon(Icons.bookmark_border, size: 18),
          label: Text(l10n.workWantToRead),
        ),
        if (listings.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => context.push(
              '/books/${listings.first.id}',
              extra: listings.first.owner,
            ),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text(l10n.workRequestSwap),
          ),
        OutlinedButton.icon(
          onPressed: () =>
              OwnedBooksSection.listBook(context, widget.work.book),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: Text(l10n.shelfListItNow),
        ),
      ],
    );
  }
}

/// Recenziile din aplicație. Stau DEASUPRA oricărei surse externe: sunt
/// scrise de oameni pe care userul îi poate întâlni la un schimb, deci
/// cântăresc altfel decât un rating agregat de altundeva.
class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.work});
  final BookWork work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final myUserId = authState is AuthAuthenticated ? authState.user.id : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child:
                  Text(l10n.workReviewsTitle, style: theme.textTheme.titleLarge),
            ),
            if (myUserId != null)
              TextButton.icon(
                onPressed: () async {
                  final saved =
                      await showReviewSheet(context, ref, book: work.book);
                  if (saved == true) ref.invalidate(bookWorkProvider(work.book.id));
                },
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: Text(l10n.workWriteReview),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (work.reviews.reviews.isEmpty)
          Text(
            l10n.workNoReviews,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          )
        else
          for (final review in work.reviews.reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReviewTile(
                review: review,
                isMine: review.userId == myUserId,
                workBookId: work.book.id,
              ),
            ),
      ],
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({
    required this.review,
    required this.isMine,
    required this.workBookId,
  });

  final BookReview review;
  final bool isMine;

  /// Ediția a cărei pagină e deschisă - pentru invalidare după ștergere.
  final String workBookId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(reviewsRepositoryProvider).remove(review.bookId);
      ref.invalidate(bookWorkProvider(workBookId));
      ref.invalidate(myReviewProvider(review.bookId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.commonGenericError)));
      }
    }
  }

  /// „Raportează" e separat de ștergere, în mod deliberat: o recenzie poate fi
  /// ștearsă DOAR de autorul ei, iar oricine altcineva o poate doar raporta -
  /// vezi ReviewsService.remove / reportReview.
  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (context) => ReportReasonDialog(target: ReportTargetKind.content),
    );
    if (reason == null) return;
    try {
      await ref.read(reviewsRepositoryProvider).report(review.id, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.reportSubmitted)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.commonGenericError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: review.authorAvatar != null
                      ? NetworkImage(review.authorAvatar!)
                      : null,
                  child: review.authorAvatar == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    review.authorName ?? l10n.commonAnonymousUser,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StarRating(rating: review.rating.toDouble(), size: 14),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    if (value == 'delete') _delete(context, ref);
                    if (value == 'report') _report(context, ref);
                  },
                  itemBuilder: (context) => [
                    if (isMine)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.workDeleteReview),
                      )
                    else
                      PopupMenuItem(
                        value: 'report',
                        child: Text(l10n.workReportReview),
                      ),
                  ],
                ),
              ],
            ),
            if (review.text != null && review.text!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.text!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Exemplarele listate în aplicație, sub recenzii - „unde o găsesc acum".
class _ListingsSection extends StatelessWidget {
  const _ListingsSection({required this.work});
  final BookWork work;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.workListingsTitle(work.listings.length),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (work.listings.isEmpty)
          Text(
            l10n.workNoListings,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: kBookCardMaxWidth,
              mainAxisSpacing: kBookGridMainAxisSpacing,
              crossAxisSpacing: kBookGridCrossAxisSpacing,
              childAspectRatio: kBookCardAspectRatio,
            ),
            itemCount: work.listings.length,
            itemBuilder: (context, index) {
              final listing = work.listings[index];
              return BookCard(
                userBook: listing,
                onTap: () =>
                    context.push('/books/${listing.id}', extra: listing.owner),
              );
            },
          ),
      ],
    );
  }
}

/// Cele cinci steluțe, în varianta „doar afișare". Introducerea notei se face
/// în `review_sheet.dart`.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 18});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star
                : rating >= i - 0.5
                    ? Icons.star_half
                    : Icons.star_border,
            size: size,
            color: AppColors.accent,
          ),
      ],
    );
  }
}
