import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_book.dart';
import '../../data/models/wishlist_item.dart';
import '../../features/wishlist/application/wishlist_controller.dart';
import 'book_cover.dart';
import 'listing_score_badge.dart';
import 'wishlist_source_icon.dart';

/// Card compact pentru o carte, cu copertă, buton inimă (adăugare rapidă la
/// wishlist), indicator preț/schimb și titlu + autor + locație dedesubt.
///
/// `width == null` => cardul umple lățimea părintelui (celula de GridView din
/// home/discover). O lățime explicită e folosită de carusele orizontale.
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.userBook,
    this.onTap,
    this.width,
    this.showWishlistHeart = true,
  });

  final UserBook userBook;
  final VoidCallback? onTap;
  final double? width;

  /// Fals pe cărțile proprii (My Shelf): nu are sens să adaugi propria carte
  /// la wishlist, iar inima se suprapunea peste meniul/butonul de acțiuni din
  /// colțul din dreapta sus al cardului (Milestone 19).
  final bool showWishlistHeart;

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.foreground.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookCover.expand(
                    // primaryImageUrl respectă steluța userului (mainPhotoUrl)
                    // înainte de coperta oficială - fără asta, alegerea
                    // explicită de pe o poză proprie nu se vedea niciodată
                    // pe carduri (aici se folosea direct book.coverUrl).
                    url: userBook.primaryImageUrl,
                    fallbackUrl:
                        userBook.photos.isNotEmpty ? userBook.photos.first : null,
                    title: userBook.book.title,
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: ListingScoreBadge(userBookId: userBook.id),
                  ),
                  if (showWishlistHeart)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _WishlistHeart(bookId: userBook.book.id),
                    ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: _PriceBadge(userBook: userBook),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            userBook.book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.foreground,
            ),
          ),
          if (userBook.book.author != null)
            Text(
              userBook.book.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (userBook.owner?.city != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 13, color: AppColors.mutedForeground),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    userBook.owner!.city!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }
}

/// Badge din colțul dreapta-jos al coperții: preț (vânzare/licitație) sau o
/// iconiță de schimb dacă e disponibilă la swap. Prioritate: licitație >
/// vânzare > swap - un anunț poate fi mai multe deodată, arătăm cel mai
/// „acționabil" preț.
class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.userBook});
  final UserBook userBook;

  @override
  Widget build(BuildContext context) {
    if (userBook.isAuction && userBook.auction != null) {
      return _badge(
        context,
        icon: Icons.gavel,
        label: context.l10n.priceLei(userBook.auction!.currentPrice.toStringAsFixed(0)),
        color: AppColors.accent,
      );
    }
    if (userBook.isForSale && userBook.salePrice != null) {
      return _badge(
        context,
        icon: userBook.salePrice == 0 ? Icons.volunteer_activism_outlined : null,
        label: userBook.salePrice == 0
            ? context.l10n.shareListingModeDonation
            : context.l10n.priceLei(userBook.salePrice!.toStringAsFixed(0)),
        color: AppColors.accent,
      );
    }
    if (userBook.availableForSwap) {
      return _badge(
        context,
        icon: Icons.swap_horiz,
        label: context.l10n.bookAvailableForSwapShort,
        color: AppColors.primary,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _badge(
    BuildContext context, {
    IconData? icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Buton inimă din colțul dreapta-sus al coperții pentru adăugare rapidă la
/// wishlist. Trece prin `wishlistControllerProvider` (nu direct prin
/// repository) - altfel starea din Wishlist screen nu se actualiza decât
/// după un refresh manual, pentru că cele două nu mai știau una de alta.
/// Starea inimii vine din controller, nu dintr-un bool local - altfel cardul
/// pornea mereu gol chiar și pentru cărți deja pe wishlist.
class _WishlistHeart extends ConsumerStatefulWidget {
  const _WishlistHeart({required this.bookId});
  final String bookId;

  @override
  ConsumerState<_WishlistHeart> createState() => _WishlistHeartState();
}

class _WishlistHeartState extends ConsumerState<_WishlistHeart> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(wishlistControllerProvider.notifier).toggle(widget.bookId);
    } catch (e) {
      // Cazul real întâlnit: limita gratuită de cărți/licitații urmărite -
      // backendul întoarce un mesaj clar (403), dar înainte era înghițit
      // silențios și inima doar revenea la alb, fără explicație.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'] is List
            ? (data['message'] as List).join(', ')
            : data['message'].toString();
      }
    }
    return context.l10n.bookDetailWishlistError;
  }

  @override
  Widget build(BuildContext context) {
    // Un singur select pe listă: întoarce sursa rândului de wishlist (sau null
    // dacă nu e pe listă). Așa cardul știe și DACĂ e la favorite, și CUM a
    // ajuns acolo, fără un al doilea apel per card.
    final source = ref.watch(
      wishlistControllerProvider.select((s) {
        for (final item in s.value ?? const <WishlistItem>[]) {
          if (item.book.id == widget.bookId) return item.source;
        }
        return null;
      }),
    );
    final wishlisted = source != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(
          wishlistIconFor(source, wishlisted: wishlisted),
          size: 17,
          color: wishlistIconColorFor(
            source,
            wishlisted: wishlisted,
            inactive: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
