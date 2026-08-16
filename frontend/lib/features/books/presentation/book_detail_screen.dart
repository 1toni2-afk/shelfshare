import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../data/models/price_offer.dart';
import '../../../shared/widgets/report_reason_dialog.dart';
import '../../../shared/widgets/wishlist_source_icon.dart';
import '../../../data/models/wishlist_item.dart';
import '../../../shared/utils/share_link.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../collections/presentation/add_to_collection_sheet.dart';
import 'browse_screen.dart';
import '../../chat/data/chat_repository.dart';
import '../../exchanges/data/exchanges_repository.dart';
import '../../offers/data/offers_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../../wishlist/application/wishlist_controller.dart';
import '../application/book_detail_controller.dart';
import '../data/books_repository.dart';
import 'edit_listing_sheet.dart';

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
  bool _redirectedToAuction = false;

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
    final currentBook = async.value;
    final bookId = currentBook?.book.id;
    final currentOwner = currentBook?.owner ?? widget.fallbackOwner;
    final authState = ref.watch(authControllerProvider);
    final isOwnBook = currentBook != null &&
        authState is AuthAuthenticated &&
        authState.user.id == currentBook.userId;
    // Sursa de adevăr pentru inimă: serverul (isWishlisted din detaliu). Lista
    // de wishlist a clientului rămâne un fallback optimist ca inima să reacționeze
    // instant la toggle, înainte de refetch-ul detaliului.
    final wishlistState = ref.watch(wishlistControllerProvider);
    WishlistItem? localWishlistRow;
    for (final item in wishlistState.value ?? const <WishlistItem>[]) {
      if (item.book.id == bookId) {
        localWishlistRow = item;
        break;
      }
    }
    final isWishlisted = bookId != null &&
        ((currentBook?.isWishlisted ?? false) || localWishlistRow != null);
    // Sursa: la fel ca inima, serverul are prioritate, cu lista locală drept
    // fallback optimist imediat după toggle.
    final wishlistSource =
        currentBook?.wishlistSource ?? localWishlistRow?.source;
    final l10n = context.l10n;

    // Anunțurile de tip licitație au propriul ecran (cu bid-uri live, buy-now
    // etc.) - dacă ajungem aici (din browse/home/bibliotecă, care nu știu
    // să distingă tipul de anunț la navigare), redirecționăm automat spre
    // /auctions/:id, altfel utilizatorul nu are cum să liciteze.
    final auctionId = currentBook?.isAuction == true ? currentBook?.auction?.id : null;
    if (auctionId != null && !_redirectedToAuction) {
      _redirectedToAuction = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/auctions/$auctionId');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookDetailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.profileCopyLink,
            onPressed: () => shareAppLink(context, '/books/${widget.userBookId}'),
          ),
          // Editează: doar pe propriul anunț. Deschide aceeași foaie de editare
          // completă ca din bibliotecă (toate câmpurile). (Milestone 18)
          if (currentBook != null && isOwnBook)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.libraryEditListing,
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => EditListingSheet(userBook: currentBook),
                );
                // Reîncărcăm detaliul ca modificările să apară imediat.
                ref.invalidate(bookDetailProvider(widget.userBookId));
              },
            ),
          if (currentBook != null && currentOwner != null && !isOwnBook)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: l10n.bookDetailReportTooltip,
              onPressed: () => _reportListing(currentBook, currentOwner),
            ),
          // Inima nu apare pe propria carte - nu-ți poți pune la favorite ceea
          // ce oferi tu (blocat și pe backend). Lângă inimă: câți useri au
          // titlul la favorite.
          if (bookId != null && !isOwnBook)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((currentBook?.favoriteCount ?? 0) > 0)
                  Text(
                    '${currentBook!.favoriteCount}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                IconButton(
                  icon: Icon(
                    wishlistIconFor(wishlistSource, wishlisted: isWishlisted),
                  ),
                  color: wishlistIconColorFor(
                    wishlistSource,
                    wishlisted: isWishlisted,
                  ),
                  onPressed: () async {
                    await ref
                        .read(wishlistControllerProvider.notifier)
                        .toggle(bookId);
                    // Reîncărcăm detaliul ca numărul de favorite de lângă inimă
                    // să reflecte imediat toggle-ul propriu.
                    ref.invalidate(bookDetailProvider(widget.userBookId));
                  },
                ),
              ],
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

/// Prag peste care afișăm layout-ul „desktop" din mockup (copertă | info |
/// carduri lateral). Sub el, totul se stivuiește pe o coloană (mobil).
const double _kDetailWideBreakpoint = 900.0;

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
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;
    final isOwnBook = currentUserId != null && currentUserId == book.userId;
    final isPremium = authState is AuthAuthenticated && authState.user.isPremium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kDetailWideBreakpoint;

        final cover = _CoverPanel(
          book: book,
          isOwnBook: isOwnBook,
          canPromote: isOwnBook && isPremium,
        );
        final main = _MainInfoPanel(
          book: book,
          isOwnBook: isOwnBook,
          onRequestExchange: onRequestExchange,
          onMakeOffer: onMakeOffer,
        );
        final sidebar = _SidebarPanel(
          book: book,
          owner: owner,
          isOwnBook: isOwnBook,
          onMessageOwner: onMessageOwner,
        );
        final similar = _SimilarBooksSection(userBookId: book.id);

        if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 300, child: cover),
                        const SizedBox(width: 40),
                        Expanded(child: main),
                        const SizedBox(width: 28),
                        SizedBox(width: 320, child: sidebar),
                      ],
                    ),
                    const SizedBox(height: 44),
                    similar,
                  ],
                ),
              ),
            ),
          );
        }

        // Mobil: totul pe o coloană, în ordinea firească de citire. Coperta
        // se întinde pe toată lățimea containerului cu aspect ratio fix
        // (5/7) - pe un telefon normal asta dă o înălțime rezonabilă, dar
        // pe o fereastră de desktop îngustată sub pragul de 900 (ex. jumătate
        // de ecran), lățimea disponibilă e mult mai mare decât a unui telefon,
        // deci înălțimea rezultată devine uriașă. Un plafon de lățime ține
        // coperta la o dimensiune rezonabilă indiferent cât de lat e
        // containerul, fără să afecteze telefoanele (sub plafon oricum).
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: cover,
                ),
              ),
              const SizedBox(height: 24),
              main,
              const SizedBox(height: 24),
              sidebar,
              const SizedBox(height: 32),
              similar,
            ],
          ),
        );
      },
    );
  }
}

/// Lista de imagini pentru carusel, cu `primaryImageUrl` mereu prima (coperta
/// oficială implicit, sau poza starată de user), urmată de restul pozelor
/// proprii urcate, fără duplicate.
List<String> _coverGalleryImages(UserBook book) {
  final primary = book.primaryImageUrl;
  final rest = book.photos.where((p) => p != primary);
  return [?primary, ...rest];
}

/// Coloana din stânga: coperta mare + preț (dacă e la vânzare) + contorul de
/// vizualizări + acțiunile de listă (colecții, promovare).
class _CoverPanel extends ConsumerWidget {
  const _CoverPanel({
    required this.book,
    required this.isOwnBook,
    required this.canPromote,
  });
  final UserBook book;
  final bool isOwnBook;
  final bool canPromote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Imaginea principală urmează `primaryImageUrl` (coperta oficială
        // implicit, sau poza proprie aleasă explicit cu steluța) - nu doar
        // "are poze proprii => le arată pe alea", cum era înainte, ceea ce
        // ignora coperta oficială chiar și când userul nu alesese nimic.
        // Restul pozelor proprii rămân răsfoibile prin swipe, doar nu mai
        // sar peste coperta oficială ca primă imagine.
        _coverGalleryImages(book).length > 1
            ? _BookPhotoCarousel(photos: _coverGalleryImages(book))
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 5 / 7,
                  child: BookCover(
                    url: book.primaryImageUrl,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
        if (book.isForSale && book.salePrice != null) ...[
          const SizedBox(height: 16),
          Center(
            child: book.salePrice == 0
                ? Text(
                    l10n.shareListingModeDonation,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                  )
                : _PriceBlock(book: book),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: _AddToCollectionButton(bookId: book.book.id)),
            if (book.book.description != null && book.book.description!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(child: _AboutBookButton(book: book.book)),
            ],
          ],
        ),
        if (canPromote) ...[
          const SizedBox(height: 8),
          _PromoteButton(userBookId: book.id, isPromoted: book.isPromoted),
        ],
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showViewStats(context, ref, book.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: AppColors.mutedForeground),
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
        if (book.photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: book.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openPhotoViewer(context, book.photos, index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    book.photos[index],
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 92,
                      height: 92,
                      color: AppColors.muted,
                      child: Icon(Icons.broken_image_outlined, color: AppColors.mutedForeground),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Poza mare devine un carusel cu swipe atunci când exemplarul are mai multe
/// poze proprii - înainte, singura cale de a trece printre ele era să dai
/// tap pe una din miniaturile de mai jos ca să deschizi viewer-ul pe tot
/// ecranul. Tap pe imagine tot deschide viewer-ul (pentru zoom), dar swipe-ul
/// direct pe poza mare funcționează fără el.
class _BookPhotoCarousel extends StatefulWidget {
  const _BookPhotoCarousel({required this.photos});
  final List<String> photos;

  @override
  State<_BookPhotoCarousel> createState() => _BookPhotoCarouselState();
}

class _BookPhotoCarouselState extends State<_BookPhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 5 / 7,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openPhotoViewer(context, widget.photos, index),
                child: Image.network(
                  widget.photos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.muted,
                    child: Icon(Icons.broken_image_outlined, color: AppColors.mutedForeground, size: 40),
                  ),
                ),
              ),
            ),
            if (widget.photos.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.photos.length; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 8 : 6,
                        height: i == _index ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 2),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Coloana centrală: titlu, autor, badge de gen, meta (limbă/an/pagini),
/// taguri, descriere cu „Show more", butoanele de acțiune și detaliile.
class _MainInfoPanel extends StatefulWidget {
  const _MainInfoPanel({
    required this.book,
    required this.isOwnBook,
    required this.onRequestExchange,
    required this.onMakeOffer,
  });
  final UserBook book;
  final bool isOwnBook;
  final VoidCallback onRequestExchange;
  final VoidCallback onMakeOffer;

  @override
  State<_MainInfoPanel> createState() => _MainInfoPanelState();
}

class _MainInfoPanelState extends State<_MainInfoPanel> {
  bool _descriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final description = book.book.description;
    final hasLongDescription =
        description != null && description.length > 240;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(book.book.title, style: theme.textTheme.headlineMedium),
        if (book.book.author != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => context.push(
              '/browse',
              extra: SearchScreenArgs(author: book.book.author!),
            ),
            child: Text(
              book.book.author!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        // Rând de badge-uri: gen + stare. (Cartea nu are rating agregat, deci
        // nu inventăm unul - vezi cardul „Owned by" pentru reputația userului.)
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (book.book.genre != null) _GenrePill(label: book.book.genre!),
            _OutlinePill(
              icon: Icons.auto_stories_outlined,
              label: book.condition.label(l10n),
            ),
            if (book.isHardcover)
              _OutlinePill(
                icon: Icons.menu_book_outlined,
                label: l10n.bookDetailHardcoverChip,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Meta cu iconițe, ca în mockup: limbă · an · pagini.
        Wrap(
          spacing: 22,
          runSpacing: 8,
          children: [
            if (book.language != null)
              _MetaItem(icon: Icons.translate_outlined, text: book.language!),
            if (book.book.publishedYear != null)
              _MetaItem(
                icon: Icons.calendar_today_outlined,
                text: '${book.book.publishedYear}',
              ),
            if (book.book.pageCount != null)
              _MetaItem(
                icon: Icons.description_outlined,
                text: '${l10n.bookDetailPagesLabel}: ${book.book.pageCount}',
              ),
          ],
        ),
        if (book.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: book.tags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _TagChip(label: book.tags[index]),
            ),
          ),
        ],
        // Nota userului la exemplarul lui (UserBook.description) - distinctă
        // de descrierea operei mai jos, care vine din ISBN/catalog și e
        // aceeași pentru toate exemplarele acestui titlu. Fără secțiunea asta,
        // orice text scris la +Share la pasul de descriere era salvat, dar nu
        // apărea nicăieri pe pagina anunțului.
        if (book.description != null && book.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.bookDetailSellerNoteTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            book.description!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.bookDetailDescriptionTitle,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: Text(
              description,
              maxLines: _descriptionExpanded ? null : 3,
              overflow: _descriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          if (hasLongDescription)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(
                  () => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _descriptionExpanded
                          ? l10n.commonShowLess
                          : l10n.commonShowMore,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.accent),
                    ),
                    Icon(
                      _descriptionExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (!widget.isOwnBook) ...[
          const SizedBox(height: 24),
          _ActionButtons(
            book: book,
            onRequestExchange: widget.onRequestExchange,
            onMakeOffer: widget.onMakeOffer,
          ),
        ],
        if (book.book.publisher != null) ...[
          const SizedBox(height: 28),
          Text(l10n.bookDetailDetailsTitle,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _DetailRow(
              label: l10n.bookDetailPublisherLabel,
              value: book.book.publisher!),
        ],
        const SizedBox(height: 24),
        _HistorySection(userBookId: book.id),
      ],
    );
  }
}

/// Butoanele „Request exchange" / „Make an offer" + textul de sub ele, ca în
/// mockup.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.book,
    required this.onRequestExchange,
    required this.onMakeOffer,
  });
  final UserBook book;
  final VoidCallback onRequestExchange;
  final VoidCallback onMakeOffer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Al doilea buton („Fă o ofertă") apare fie pe un anunț de vânzare
    // negociabil, fie pe unul de tip Schimb pe care proprietarul a bifat
    // „sau vinde cu X lei" la listare (UserBook.swapSalePrice).
    final canOffer =
        (book.isForSale && book.isNegotiable) || book.swapSalePrice != null;
    final isDonation = book.isForSale && book.salePrice == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: book.availableForSwap ? onRequestExchange : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(!book.availableForSwap
                    ? l10n.bookDetailUnavailableForExchange
                    : isDonation
                        ? l10n.bookDetailRequestDonation
                        : l10n.bookDetailRequestExchange),
              ),
            ),
            if (canOffer) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onMakeOffer,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(l10n.bookDetailMakeOffer),
                ),
              ),
            ],
          ],
        ),
        if (book.availableForSwap) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.bookDetailAvailableForExchangeHint,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
        ],
      ],
    );
  }
}

/// Coloana din dreapta: cardul „Owned by" + cardul de disponibilitate/locație.
class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.book,
    required this.owner,
    required this.isOwnBook,
    required this.onMessageOwner,
  });
  final UserBook book;
  final PublicUser? owner;
  final bool isOwnBook;
  final VoidCallback? onMessageOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (owner != null) ...[
          _OwnedByCard(
            owner: owner!,
            isOwnBook: isOwnBook,
            onMessageOwner: onMessageOwner,
          ),
          const SizedBox(height: 16),
        ],
        _AvailabilityCard(book: book, owner: owner),
      ],
    );
  }
}

/// Container-ul cu stil de card folosit în bara laterală (fundal card + bordură
/// + colțuri rotunjite), cu titlu opțional și un punct de accent.
class _SidebarCard extends StatelessWidget {
  const _SidebarCard({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(title!, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

class _OwnedByCard extends StatelessWidget {
  const _OwnedByCard({
    required this.owner,
    required this.isOwnBook,
    required this.onMessageOwner,
  });
  final PublicUser owner;
  final bool isOwnBook;
  final VoidCallback? onMessageOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SidebarCard(
      title: l10n.bookDetailOwnerTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/users/${owner.id}', extra: owner),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: owner.profileImage != null
                      ? NetworkImage(owner.profileImage!)
                      : null,
                  child: owner.profileImage == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner.name ?? l10n.commonUnknownUser,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (owner.city != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.mutedForeground),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                owner.city!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.mutedForeground),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            owner.rating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isOwnBook && onMessageOwner != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onMessageOwner,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(l10n.bookDetailMessageOwner),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.book, required this.owner});
  final UserBook book;
  final PublicUser? owner;

  Future<void> _openMap(String city) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(city)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final available = book.availableForSwap;
    final city = book.city ?? owner?.city;

    return _SidebarCard(
      title: l10n.bookDetailAvailabilityTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 18,
                  color: available
                      ? AppColors.success
                      : AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                available
                    ? l10n.bookDetailAvailableChip
                    : l10n.libraryUnavailable,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      available ? AppColors.success : AppColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (available) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                l10n.bookDetailReadyToExchange,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedForeground),
              ),
            ),
          ],
          if (city != null) ...[
            const Divider(height: 28),
            Text(
              l10n.bookDetailLocationTitle,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(city, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openMap(city),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.bookDetailViewOnMap,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.accent),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new,
                      size: 13, color: AppColors.accent),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge de gen, plin cu accent translucid (ex. „Classic").
class _GenrePill extends StatelessWidget {
  const _GenrePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Pill cu bordură + iconiță (stare, copertă cartonată).
class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.mutedForeground),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Element de meta (iconiță + text) din rândul limbă/an/pagini.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}

/// Chip de tag al listării (stil hashtag discret).
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Deschide sheet-ul cu toate listele în care poate intra cartea: rafturile
/// fixe (citesc / vreau să citesc / citită) și colecțiile proprii. Ambele cer
/// autentificare pe backend (JwtAuthGuard), deci butonul e ascuns altfel.
class _AddToCollectionButton extends ConsumerWidget {
  const _AddToCollectionButton({required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    return Center(
      child: OutlinedButton.icon(
        onPressed: () => showAddToCollectionSheet(context, bookId: bookId),
        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
        label: Text(context.l10n.collectionsAddToTitle),
      ),
    );
  }
}

/// Buton dedicat lângă "Add to collection" care arată descrierea din catalog
/// (ISBN) într-un bottom sheet - fără să oblige userul să deruleze pagina
/// până jos, unde secțiunea "Descriere" oricum apare (dacă e destul de lungă).
class _AboutBookButton extends StatelessWidget {
  const _AboutBookButton({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _AboutBookSheet(book: book),
      ),
      icon: const Icon(Icons.info_outline, size: 18),
      label: Text(context.l10n.bookDetailAboutButton),
    );
  }
}

class _AboutBookSheet extends StatelessWidget {
  const _AboutBookSheet({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: ListView(
          controller: scrollController,
          children: [
            Text(book.title, style: Theme.of(context).textTheme.titleLarge),
            if (book.author != null) ...[
              const SizedBox(height: 4),
              Text(
                book.author!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.mutedForeground),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (book.genre != null) _MetaItem(icon: Icons.category_outlined, text: book.genre!),
                if (book.publishedYear != null)
                  _MetaItem(icon: Icons.calendar_today_outlined, text: '${book.publishedYear}'),
                if (book.pageCount != null)
                  _MetaItem(
                    icon: Icons.description_outlined,
                    text: '${l10n.bookDetailPagesLabel}: ${book.pageCount}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(book.description ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _PromoteButton extends ConsumerWidget {
  const _PromoteButton({required this.userBookId, required this.isPromoted});
  final String userBookId;
  final bool isPromoted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Center(
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref.read(booksRepositoryProvider).togglePromoted(userBookId);
          ref.invalidate(bookDetailProvider(userBookId));
        },
        icon: Icon(Icons.trending_up, size: 18, color: isPromoted ? AppColors.warning : null),
        label: Text(isPromoted ? l10n.premiumUnpromoteListing : l10n.premiumPromoteListing),
      ),
    );
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
    return InkWell(
      // Verigile din trecut duc la anunțul lor propriu - veriga curentă (cea
      // de pe pagina asta) nu face nimic, ca să nu apese pe ea din reflex.
      onTap: entry.isCurrent ? null : () => context.push('/books/${entry.userBookId}'),
      child: Padding(
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
                  '${entry.condition.label(l10n)} · ${l10n.bookDetailHistoryListedOn(_formatDate(entry.listedAt))}'
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
      final (_, conversationId) = await ref.read(exchangesRepositoryProvider).createRequest(
            requestedBookId: widget.requestedBook.id,
            offeredBookId: _offeredBookId,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.bookDetailRequestSent)));
        // Cererea e postată direct ca mesaj în chat - ducem userul acolo ca
        // să vadă imediat cardul, nu doar un toast (la fel ca la oferta de preț).
        if (conversationId != null) {
          context.push('/chat/$conversationId', extra: widget.requestedBook.owner);
        }
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
  /// Pretul de referinta: cel de vanzare, sau cel din „sau vinde cu X lei"
  /// de pe un anunt de tip Schimb (vezi UserBook.swapSalePrice).
  double? get _askingPrice => widget.book.salePrice ?? widget.book.swapSalePrice;

  late final _amountController =
      TextEditingController(text: _askingPrice?.toStringAsFixed(0));
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
      final (_, conversationId) = await ref.read(offersRepositoryProvider).createOffer(
            widget.book.id,
            amount: amount,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.bookDetailOfferSent)));
        // Oferta e postată direct ca mesaj în chat - ducem cumpărătorul acolo
        // ca să vadă imediat cardul de ofertă, nu doar un toast.
        if (conversationId != null) {
          context.push('/chat/$conversationId', extra: widget.book.owner);
        }
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
            if (_askingPrice != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.bookDetailAskingPrice(l10n.priceLei(_askingPrice!.toStringAsFixed(0))),
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
              maxLines: 2,
              maxLength: 50,
              decoration: InputDecoration(labelText: l10n.bookDetailMessageOptional),
            ),
            const SizedBox(height: 8),
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

/// Deschide vizualizatorul de poze printr-o rută go_router adevărată
/// (/photo-viewer), nu direct pe Navigator-ul rădăcină - fără asta, web nu
/// avea nicio intrare nouă în istoricul browser-ului la deschidere, deci un
/// singur click pe "back"-ul browser-ului sărea peste tot ecranul anunțului
/// (nu doar peste poză) direct la pagina de dinainte (discover/home).
void _openPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
  context.push('/photo-viewer', extra: (photos, initialIndex));
}

/// Vizualizator plin-ecran cu zoom (pinch) și navigare între poze prin swipe.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.photos, required this.initialIndex});
  final List<String> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final _pageController = PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `canPop: true` explicit + un handler care nu face nimic altceva decât
    // să lase pop-ul să treacă - fără PopScope, gestul de swipe-back pe
    // mobil putea, în anumite condiții de tranziție, sări peste ruta asta
    // (împinsă separat, cu propriul MaterialPageRoute) direct la ecranul de
    // dedesubt (lista de poze de pe anunț), ieșind din tot anunțul în loc să
    // închidă doar poza mărită. Cu PopScope, acest pop e mereu tratat ca
    // aparținând STRICT acestei rute.
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          // X explicit în stânga-sus - fără el, singura cale de închidere era
          // swipe-back, ușor de confundat cu swipe-back-ul care te scoate de
          // pe tot ecranul anunțului.
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('${_currentIndex + 1} / ${widget.photos.length}'),
        ),
        body: Stack(
          children: [
            PageView.builder(
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
            if (widget.photos.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _PhotoNavArrow(
                    icon: Icons.chevron_left,
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                  )),
                ),
              if (_currentIndex < widget.photos.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _PhotoNavArrow(
                    icon: Icons.chevron_right,
                    onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                  )),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoNavArrow extends StatelessWidget {
  const _PhotoNavArrow({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
