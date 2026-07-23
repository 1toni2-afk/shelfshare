import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../data/models/price_offer.dart';
import '../../../shared/widgets/report_reason_dialog.dart';
import '../../../shared/utils/share_link.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../chat/data/chat_repository.dart';
import '../../exchanges/data/exchanges_repository.dart';
import '../../offers/data/offers_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../../wishlist/application/wishlist_controller.dart';
import '../application/book_detail_controller.dart';
import '../data/books_repository.dart';
import '../data/bookshelf_repository.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({super.key, required this.userBookId, this.fallbackOwner});
  final String userBookId;

  /// Owner deja cunoscut din ecranul de proveniență (Home/Browse) - afișat
  /// instant, înainte ca fetch-ul de detalii să se termine.
  final PublicUser? fallbackOwner;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _sheetOpen = false;

  Future<void> _requestExchange(UserBook book) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RequestExchangeSheet(requestedBook: book),
    );
    _sheetOpen = false;
  }

  Future<void> _messageOwner(PublicUser owner) async {
    final conversation = await ref.read(chatRepositoryProvider).startConversation(owner.id);
    if (mounted) {
      context.push('/chat/${conversation.id}', extra: owner);
    }
  }

  Future<void> _makeOffer(UserBook book) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MakeOfferSheet(book: book),
    );
    _sheetOpen = false;
  }

  Future<void> _reportListing(UserBook book, PublicUser owner) async {
    final l10n = context.l10n;
    final result = await showDialog<ReportReason>(
      context: context,
      builder: (context) => const ReportReasonDialog(),
    );
    if (result == null) return;
    try {
      await ref.read(safetyRepositoryProvider).reportUser(
            owner.id,
            reason: result,
            userBookId: book.id,
            details: l10n.bookDetailReportedFrom(book.book.title),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.bookDetailReportSent)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.bookDetailReportError)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookDetailProvider(widget.userBookId));
    final bookId = async.value?.book.id;
    final wishlistState = ref.watch(wishlistControllerProvider);
    final isWishlisted = bookId != null &&
        (wishlistState.value ?? const []).any((item) => item.book.id == bookId);
    final currentBook = async.value;
    final currentOwner = currentBook?.owner ?? widget.fallbackOwner;
    final authState = ref.watch(authControllerProvider);
    final isOwnBook = currentBook != null &&
        authState is AuthAuthenticated &&
        authState.user.id == currentBook.userId;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookDetailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.profileCopyLink,
            onPressed: () => copyShareLink(context, '/books/${widget.userBookId}'),
          ),
          if (currentBook != null && currentOwner != null && !isOwnBook)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: l10n.bookDetailReportTooltip,
              onPressed: () => _reportListing(currentBook, currentOwner),
            ),
          if (bookId != null)
            IconButton(
              icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border),
              color: isWishlisted ? AppColors.destructive : null,
              onPressed: () => ref.read(wishlistControllerProvider.notifier).toggle(bookId),
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          data: (book) {
            final owner = book.owner ?? widget.fallbackOwner;
            return _BookDetailContent(
              book: book,
              owner: owner,
              onRequestExchange: () => _requestExchange(book),
              onMessageOwner: owner == null ? null : () => _messageOwner(owner),
              onMakeOffer: () => _makeOffer(book),
            );
          },
          loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
          error: (error, _) => CenteredScrollable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.bookDetailLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(bookDetailProvider(widget.userBookId)),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showViewStats(BuildContext context, WidgetRef ref, String userBookId) async {
  final l10n = context.l10n;
  showDialog<void>(
    context: context,
    builder: (context) => FutureBuilder(
      future: ref.read(booksRepositoryProvider).getViewStats(userBookId),
      builder: (context, snapshot) {
        return AlertDialog(
          title: Text(l10n.bookDetailViewsTitle),
          content: switch (snapshot.connectionState) {
            ConnectionState.waiting => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
            _ when snapshot.hasError => Text(l10n.bookDetailViewsLoadError),
            _ => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.bookDetailUniqueViews(snapshot.data!.unique)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.bookDetailTotalViews(snapshot.data!.total),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
          },
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        );
      },
    ),
  );
}

class _BookDetailContent extends ConsumerWidget {
  const _BookDetailContent({
    required this.book,
    required this.owner,
    required this.onRequestExchange,
    required this.onMessageOwner,
    required this.onMakeOffer,
  });
  final UserBook book;
  final PublicUser? owner;
  final VoidCallback onRequestExchange;
  final VoidCallback? onMessageOwner;
  final VoidCallback onMakeOffer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
    final isOwnBook = currentUserId != null && currentUserId == book.userId;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: BookCover(url: book.book.coverUrl, width: 180, height: 252)),
        const SizedBox(height: 20),
        Text(
          book.book.title,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (book.book.author != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              book.book.author!,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.mutedForeground),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(book.condition.label)),
            if (book.language != null) Chip(label: Text(book.language!)),
            if (book.isHardcover) Chip(label: Text(l10n.bookDetailHardcoverChip)),
            if (owner?.city != null)
              Chip(
                avatar: const Icon(Icons.location_on_outlined, size: 16),
                label: Text(owner!.city!),
              ),
            Chip(
              label: Text(book.availableForSwap ? l10n.bookDetailAvailableChip : l10n.libraryUnavailable),
              backgroundColor:
                  book.availableForSwap ? AppColors.accent.withValues(alpha: 0.15) : AppColors.muted,
            ),
            if (book.isForSale && !book.isNegotiable) Chip(label: Text(l10n.addBookNonNegotiable)),
          ],
        ),
        const SizedBox(height: 16),
        _ShelfStatusRow(bookId: book.book.id),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showViewStats(context, ref, book.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined, size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  l10n.bookDetailViewCount(book.viewCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (book.isForSale && book.salePrice != null) ...[
          const SizedBox(height: 16),
          Center(child: _PriceBlock(book: book)),
        ],
        if (book.book.description != null && book.book.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.bookDetailDescriptionTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(book.book.description!),
        ],
        if (book.book.genre != null ||
            book.book.publisher != null ||
            book.book.publishedYear != null ||
            book.book.pageCount != null) ...[
          const SizedBox(height: 24),
          Text(l10n.bookDetailDetailsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (book.book.genre != null) _DetailRow(label: l10n.filtersGenre, value: book.book.genre!),
          if (book.book.publisher != null) _DetailRow(label: l10n.bookDetailPublisherLabel, value: book.book.publisher!),
          if (book.book.publishedYear != null)
            _DetailRow(label: l10n.bookDetailYearLabel, value: book.book.publishedYear.toString()),
          if (book.book.pageCount != null)
            _DetailRow(label: l10n.bookDetailPagesLabel, value: book.book.pageCount.toString()),
        ],
        if (owner != null) ...[
          const SizedBox(height: 24),
          Text(l10n.bookDetailOwnerTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => context.push('/users/${owner!.id}', extra: owner),
            leading: CircleAvatar(
              backgroundImage: owner!.profileImage != null ? NetworkImage(owner!.profileImage!) : null,
              child: owner!.profileImage == null ? const Icon(Icons.person) : null,
            ),
            title: Text(owner!.name ?? l10n.commonUnknownUser),
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (owner!.city != null) ...[
                  Text(owner!.city!),
                  const Text(' · '),
                ],
                const Icon(Icons.star, size: 14, color: AppColors.accent),
                Text(' ${owner!.rating.toStringAsFixed(1)}'),
              ],
            ),
            trailing: isOwnBook
                ? null
                : IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: onMessageOwner,
                  ),
          ),
        ],
        if (book.photos.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.bookDetailPhotosTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: book.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openPhotoViewer(context, book.photos, index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    book.photos[index],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _HistorySection(userBookId: book.id),
        const SizedBox(height: 24),
        _SimilarBooksSection(userBookId: book.id),
        const SizedBox(height: 32),
        if (!isOwnBook) ...[
          if (book.availableForSwap)
            ElevatedButton(
              onPressed: onRequestExchange,
              child: Text(l10n.bookDetailRequestExchange),
            )
          else
            ElevatedButton(onPressed: null, child: Text(l10n.bookDetailUnavailableForExchange)),
          if (book.isForSale && book.isNegotiable) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onMakeOffer,
              child: Text(l10n.bookDetailMakeOffer),
            ),
          ],
        ],
      ],
    );
  }
}

/// Status personal de citit (Public Bookshelf) - independent de a deține
/// sau nu un exemplar fizic, deci vizibil doar dacă userul e autentificat
/// (backend-ul cere JwtAuthGuard).
class _ShelfStatusRow extends ConsumerWidget {
  const _ShelfStatusRow({required this.bookId});
  final String bookId;

  Future<void> _toggle(WidgetRef ref, BookshelfStatus tapped, BookshelfStatus? current) async {
    final repository = ref.read(bookshelfRepositoryProvider);
    if (current == tapped) {
      await repository.removeFromShelf(bookId);
    } else {
      await repository.setStatus(bookId, tapped);
    }
    ref.invalidate(bookshelfStatusProvider(bookId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final async = ref.watch(bookshelfStatusProvider(bookId));
    final l10n = context.l10n;

    return async.when(
      data: (current) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final status in BookshelfStatus.values)
            ChoiceChip(
              label: Text(_labelFor(l10n, status)),
              selected: current == status,
              onSelected: (_) => _toggle(ref, status, current),
            ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  String _labelFor(AppLocalizations l10n, BookshelfStatus status) {
    switch (status) {
      case BookshelfStatus.reading:
        return l10n.bookshelfTabReading;
      case BookshelfStatus.wantToRead:
        return l10n.bookshelfTabWantToRead;
      case BookshelfStatus.finished:
        return l10n.bookshelfTabFinished;
    }
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.userBookId});
  final String userBookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listingHistoryProvider(userBookId));
    return async.when(
      data: (history) {
        if (history.length <= 1) return const SizedBox.shrink();
        final l10n = context.l10n;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.bookDetailHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.bookDetailHistorySubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            for (final entry in history) _HistoryHop(entry: entry),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HistoryHop extends StatelessWidget {
  const _HistoryHop({required this.entry});
  final ListingHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 6,
                backgroundColor: entry.isCurrent ? AppColors.accent : AppColors.mutedForeground,
              ),
              Container(width: 2, height: entry.photos.isEmpty ? 24 : 70, color: AppColors.border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.ownerName ?? l10n.commonUnknownUser,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${entry.condition.label} · ${l10n.bookDetailHistoryListedOn(_formatDate(entry.listedAt))}'
                  '${entry.transferredAt != null ? l10n.bookDetailHistoryTransferredOn(entry.transferType == 'sale' ? l10n.bookDetailHistorySold : l10n.bookDetailHistoryExchanged, _formatDate(entry.transferredAt!)) : entry.isCurrent ? l10n.bookDetailHistoryCurrentlyOwned : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                ),
                if (entry.photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => _openPhotoViewer(context, entry.photos, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(entry.photos[i], width: 56, height: 56, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';
}

class _SimilarBooksSection extends ConsumerWidget {
  const _SimilarBooksSection({required this.userBookId});
  final String userBookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(similarBooksProvider(userBookId));
    return async.when(
      data: (similar) {
        if (similar.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.bookDetailSimilarBooksTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: similar.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => BookCard(
                  userBook: similar[index],
                  width: 130,
                  onTap: () => context.pushReplacement(
                    '/books/${similar[index].id}',
                    extra: similar[index].owner,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.book});
  final UserBook book;

  @override
  Widget build(BuildContext context) {
    final salePrice = book.salePrice!;
    final referencePrice = book.book.referencePrice;
    final referenceCurrency = book.book.referencePriceCurrency ?? '';
    final showSaving = referencePrice != null && referencePrice > salePrice;

    return Column(
      children: [
        Text(
          context.l10n.priceLei(salePrice.toStringAsFixed(0)),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
        if (showSaving) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.bookDetailLibraryPriceLabel('${referencePrice.toStringAsFixed(0)} $referenceCurrency'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.mutedForeground,
                ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _RequestExchangeSheet extends ConsumerStatefulWidget {
  const _RequestExchangeSheet({required this.requestedBook});
  final UserBook requestedBook;

  @override
  ConsumerState<_RequestExchangeSheet> createState() => _RequestExchangeSheetState();
}

class _RequestExchangeSheetState extends ConsumerState<_RequestExchangeSheet> {
  final _messageController = TextEditingController();
  String? _offeredBookId;
  bool _isSubmitting = false;
  bool _isLoadingMyBooks = true;
  List<UserBook>? _myBooks;

  @override
  void initState() {
    super.initState();
    _loadMyBooks();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMyBooks() async {
    try {
      final books = await ref.read(booksRepositoryProvider).getMyLibrary();
      if (mounted) {
        setState(() {
          _myBooks = books.where((b) => b.availableForSwap).toList();
          _isLoadingMyBooks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMyBooks = false);
    }
  }

  /// Dacă userul n-a mai trimis nicio cerere de schimb, arată un reminder
  /// de siguranță o singură dată înainte de a-l lăsa să continue.
  Future<bool> _confirmSafetyIfFirstExchange() async {
    try {
      final sent = await ref.read(exchangesRepositoryProvider).getSent();
      if (sent.isNotEmpty) return true;
    } catch (_) {
      return true; // nu blocăm userul dacă verificarea eșuează
    }
    if (!mounted) return false;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bookDetailFirstExchangeTitle),
        content: Text(l10n.bookDetailFirstExchangeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonGiveUp),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.bookDetailUnderstood),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!await _confirmSafetyIfFirstExchange()) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(exchangesRepositoryProvider).createRequest(
            requestedBookId: widget.requestedBook.id,
            offeredBookId: _offeredBookId,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.bookDetailRequestSent)));
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
            : l10n.bookDetailRequestError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bookDetailRequestedTitle(widget.requestedBook.book.title),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (_isLoadingMyBooks)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_myBooks == null || _myBooks!.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.bookDetailNoBooksToOffer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              DropdownButtonFormField<String?>(
                initialValue: _offeredBookId,
                decoration: InputDecoration(labelText: l10n.bookDetailOfferOneOfYourBooks),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.bookDetailNoOffer)),
                  for (final userBook in _myBooks!)
                    DropdownMenuItem(value: userBook.id, child: Text(userBook.book.title)),
                ],
                onChanged: (value) => setState(() => _offeredBookId = value),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.bookDetailMessageOptional),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.bookDetailSendRequest),
            ),
          ],
        ),
      ),
    );
  }
}

class _MakeOfferSheet extends ConsumerStatefulWidget {
  const _MakeOfferSheet({required this.book});
  final UserBook book;

  @override
  ConsumerState<_MakeOfferSheet> createState() => _MakeOfferSheetState();
}

class _MakeOfferSheetState extends ConsumerState<_MakeOfferSheet> {
  late final _amountController =
      TextEditingController(text: widget.book.salePrice?.toStringAsFixed(0));
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.bookDetailInvalidAmount)));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(offersRepositoryProvider).createOffer(
            widget.book.id,
            amount: amount,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.bookDetailOfferSent)));
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
            : l10n.bookDetailOfferError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bookDetailMakeOfferTitle(widget.book.book.title),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.book.salePrice != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.bookDetailAskingPrice(l10n.priceLei(widget.book.salePrice!.toStringAsFixed(0))),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.bookDetailOfferAmountLabel, suffixText: 'lei'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.bookDetailMessageOptional),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.bookDetailSendOffer),
            ),
          ],
        ),
      ),
    );
  }
}

void _openPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => _PhotoViewerScreen(photos: photos, initialIndex: initialIndex),
      fullscreenDialog: true,
    ),
  );
}

/// Vizualizator plin-ecran cu zoom (pinch) și navigare între poze prin swipe.
class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({required this.photos, required this.initialIndex});
  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final _pageController = PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(widget.photos[index], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
