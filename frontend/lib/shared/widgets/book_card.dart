import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
            if (userBook.distanceKm != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 12, color: AppColors.mutedForeground),
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
                    const Icon(Icons.person_outline, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        userBook.owner!.name ?? 'Utilizator',
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
          '${salePrice.toStringAsFixed(0)} lei',
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
