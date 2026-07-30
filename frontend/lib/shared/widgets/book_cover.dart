import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.width = 100,
    this.height = 140,
    this.borderRadius = 12,
  });

  /// Umple tot spațiul părintelui (ex. o celulă de GridView sau un AspectRatio)
  /// în loc de o dimensiune fixă - folosit de BookCard în grila responsivă.
  const BookCover.expand({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.borderRadius = 12,
  })  : width = null,
        height = null;

  final String? url;

  /// Folosit când catalogul nu are copertă - de obicei prima poză urcată de
  /// proprietar. Multe cărți (mai ales titluri românești fără ISBN) nu se
  /// găsesc în Open Library sau Google Books, dar au poza reală a exemplarului,
  /// care e oricum mai utilă cumpărătorului decât un chenar gol.
  final String? fallbackUrl;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = _firstNonEmpty([url, fallbackUrl]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: effectiveUrl == null
            ? _placeholder()
            : CachedNetworkImage(
                imageUrl: effectiveUrl,
                fit: BoxFit.cover,
                placeholder: (context, _) => _placeholder(),
                // Dacă și coperta din catalog dă eroare (link extern mort),
                // mai încercăm poza proprietarului înainte de chenarul gol.
                errorWidget: (context, _, _) {
                  final alternative = _firstNonEmpty([fallbackUrl]);
                  if (alternative == null || alternative == effectiveUrl) {
                    return _placeholder();
                  }
                  return CachedNetworkImage(
                    imageUrl: alternative,
                    fit: BoxFit.cover,
                    placeholder: (context, _) => _placeholder(),
                    errorWidget: (context, _, _) => _placeholder(),
                  );
                },
              ),
      ),
    );
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.secondary,
      child: Icon(Icons.menu_book_rounded, color: AppColors.mutedForeground, size: 32),
    );
  }
}
