import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_book.dart';
import 'book_cover.dart';

/// Card compact pentru o carte oferită la schimb, cu copertă, titlu, autor
/// și mini-profilul proprietarului (nume, oraș) - stilul din designul Figma.
class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.userBook, this.onTap, this.width = 140});

  final UserBook userBook;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(url: userBook.book.coverUrl, width: width, height: width * 1.4),
            const SizedBox(height: 8),
            Text(
              userBook.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (userBook.book.author != null)
              Text(
                userBook.book.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (userBook.isForSale && userBook.salePrice != null) ...[
              const SizedBox(height: 2),
              _PriceRow(userBook: userBook),
            ],
            if (userBook.isAuction && userBook.auction != null) ...[
              const SizedBox(height: 2),
              _AuctionRow(auction: userBook.auction!),
            ],
            if (userBook.distanceKm != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.near_me_outlined, size: 12, color: AppColors.mutedForeground),
                  const SizedBox(width: 2),
                  Text(
                    '${userBook.distanceKm!.round()} km',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            if (userBook.owner != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/users/${userBook.owner!.id}', extra: userBook.owner),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        userBook.owner!.name ?? context.l10n.commonUnknownUser,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
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

/// Prețul curent al licitației + timpul rămas, pe cardul din browse/home.
class _AuctionRow extends StatelessWidget {
  const _AuctionRow({required this.auction});
  final AuctionCardSummary auction;

  @override
  Widget build(BuildContext context) {
    final remaining = auction.endsAt.difference(DateTime.now());
    final label = remaining.isNegative
        ? context.l10n.auctionEnded
        : remaining.inHours >= 24
            ? context.l10n.auctionEndsInDays(remaining.inDays)
            : remaining.inHours >= 1
                ? context.l10n.auctionEndsInHours(remaining.inHours)
                : context.l10n.auctionEndsInMinutes(remaining.inMinutes.clamp(1, 59));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/auctions/${auction.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Icon(Icons.gavel, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            context.l10n.priceLei(auction.currentPrice.toStringAsFixed(0)),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// Prețul de vânzare al userului, plus prețul de referință din librării
/// (Google Books) atunci când e mai mare - ca userul să vadă economia.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.userBook});
  final UserBook userBook;

  @override
  Widget build(BuildContext context) {
    final salePrice = userBook.salePrice!;
    final referencePrice = userBook.book.referencePrice;
    final referenceCurrency = userBook.book.referencePriceCurrency ?? '';
    final showReference = referencePrice != null && referencePrice > salePrice;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          context.l10n.priceLei(salePrice.toStringAsFixed(0)),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
        ),
        if (showReference) ...[
          const SizedBox(width: 6),
          Text(
            '${referencePrice.toStringAsFixed(0)} $referenceCurrency',
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
