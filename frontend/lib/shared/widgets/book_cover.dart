import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Paletă (fundal, text) pentru coperțile generate din titlu - vezi
/// [BookCover._placeholder]. Aceleași 9 perechi din mockup-urile Milestone 20.
const _coverPalette = [
  (Color(0xFF12604C), Color(0xFFCFEADE)),
  (Color(0xFF4A41A3), Color(0xFFDED9FF)),
  (Color(0xFF8C3717), Color(0xFFFFD9C9)),
  (Color(0xFF17537F), Color(0xFFD3E7F7)),
  (Color(0xFF7D2C49), Color(0xFFFFD4E2)),
  (Color(0xFF4B5F16), Color(0xFFE4EFC9)),
  (Color(0xFF8A5C12), Color(0xFFFFE6BD)),
  (Color(0xFF7A2626), Color(0xFFFFD6D6)),
  (Color(0xFF2F5D63), Color(0xFFCFE9EC)),
];

(Color, Color) _coverHue(String title) {
  var h = 0;
  for (final c in title.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _coverPalette[h % _coverPalette.length];
}

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.title,
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
    this.title,
    this.borderRadius = 12,
  })  : width = null,
        height = null;

  final String? url;

  /// Folosit când catalogul nu are copertă - de obicei prima poză urcată de
  /// proprietar. Multe cărți (mai ales titluri românești fără ISBN) nu se
  /// găsesc în Open Library sau Google Books, dar au poza reală a exemplarului,
  /// care e oricum mai utilă cumpărătorului decât un chenar gol.
  final String? fallbackUrl;

  /// Titlul cărții - când nu există nicio imagine, generăm o copertă colorată
  /// (culoare derivată din hash-ul titlului) cu titlul scris pe ea, în loc de
  /// un chenar gri cu o iconiță identică pe fiecare carte fără poză. Cel mai
  /// mare câștig vizual per oră de muncă din tot proiectul - vezi mockup-urile
  /// Milestone 20.
  final String? title;
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
    final t = title?.trim();
    if (t == null || t.isEmpty) {
      return Container(
        color: AppColors.secondary,
        child: Icon(Icons.menu_book_rounded, color: AppColors.mutedForeground, size: 32),
      );
    }
    final (bg, fg) = _coverHue(t);
    return Container(
      color: bg,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      child: Text(
        t,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontSize: 11, height: 1.25, fontWeight: FontWeight.w500),
      ),
    );
  }
}
