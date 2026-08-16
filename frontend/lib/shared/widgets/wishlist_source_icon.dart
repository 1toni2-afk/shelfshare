import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/wishlist_item.dart';

/// Iconița „e pe wishlist-ul meu" pentru o carte, în funcție de cum a ajuns
/// acolo. Titlurile adăugate manual păstrează inima roșie dintotdeauna; cele
/// venite dintr-un „Yes" în Book Match primesc scânteia, ca userul să vadă
/// dintr-o privire care sunt alegerile lui explicite și care sugestiile.
///
/// Un singur loc pentru maparea asta - o folosesc și cardul din grilă, și
/// bara de sus a paginii de anunț.
IconData wishlistIconFor(WishlistSource? source, {required bool wishlisted}) {
  if (!wishlisted) return Icons.favorite_border;
  return source == WishlistSource.bookMatch
      ? Icons.auto_awesome
      : Icons.favorite;
}

Color? wishlistIconColorFor(
  WishlistSource? source, {
  required bool wishlisted,
  Color? inactive,
}) {
  if (!wishlisted) return inactive;
  return source == WishlistSource.bookMatch
      ? AppColors.primary
      : AppColors.destructive;
}
