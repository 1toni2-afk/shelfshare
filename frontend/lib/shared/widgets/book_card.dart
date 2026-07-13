import 'package:flutter/material.dart';
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
            const SizedBox(height: 4),
            if (userBook.owner != null)
              Row(
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
          ],
        ),
      ),
    );
  }
}
