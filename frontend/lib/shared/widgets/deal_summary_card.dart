import 'package:flutter/material.dart';

import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';
import '../../data/models/user_book.dart';
import 'book_cover.dart';

/// Ce trece dintr-o parte în cealaltă: cărți, bani, sau ambele (schimb cu
/// diferență în bani). O parte goală nu există într-un târg valid, dar o
/// tratăm oricum, ca un card incomplet să nu arunce.
class DealPayload {
  const DealPayload({this.books = const [], this.extraBooks = 0, this.amount});

  /// Cărțile care se dau/primesc. Prima e cea afișată cu copertă mare.
  final List<UserBook> books;

  /// Câte cărți în plus față de [books], afișate ca „+N" - listele lungi n-au
  /// loc în card.
  final int extraBooks;

  /// Suma în lei, dacă partea asta include bani.
  final double? amount;

  bool get isEmpty => books.isEmpty && amount == null;
}

/// Antetul paginii de finalizare a unui târg: ce dai, ce primești, și cu cine.
///
/// Înlocuiește două carduri aproape identice (unul în ready_to_exchange_screen,
/// unul în ready_to_sell_screen) care spuneau amândouă același lucru greșit:
/// puneau CARTEA și SUMA pe partea de „You give", iar la „You receive"
/// afișau avatarul celuilalt user. Adică, citit literal, dădeai o carte și 20
/// de lei ca să primești un om. Pe deasupra, cardul era identic indiferent de
/// partea pe care erai: și cumpărătorul, și vânzătorul vedeau „dai cartea",
/// deși cumpărătorul dă banii.
///
/// Aici cele două coloane conțin DOAR obiectele târgului, fiecare pe partea
/// care îi revine userului curent, iar celălalt om coboară pe un rând separat,
/// sub o linie: e cine te întâlnești, nu marfă.
class DealSummaryCard extends StatelessWidget {
  const DealSummaryCard({
    super.key,
    required this.give,
    required this.receive,
    required this.other,
  });

  final DealPayload give;
  final DealPayload receive;
  final PublicUser other;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Side(label: l10n.readyYouGive, payload: give),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.swap_horiz,
                            size: 20,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Side(label: l10n.readyYouReceive, payload: receive),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: other.profileImage != null
                      ? NetworkImage(other.profileImage!)
                      : null,
                  child: other.profileImage == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other.name ?? l10n.commonAnonymousUser,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (other.city != null)
                        Text(
                          l10n.readyFromCity(other.city!),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
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

/// O coloană a târgului. Cărțile se afișează cu copertă + titlu, banii ca sumă
/// mare cu iconiță - suficient de diferite vizual cât să se vadă dintr-o
/// privire ce fel de lucru trece în fiecare direcție.
class _Side extends StatelessWidget {
  const _Side({required this.label, required this.payload});

  final String label;
  final DealPayload payload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final book = payload.books.isNotEmpty ? payload.books.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 8),
        if (book != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                url: book.primaryImageUrl,
                title: book.book.title,
                width: 56,
                height: 78,
              ),
              if (payload.extraBooks > 0) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text(
                    '+${payload.extraBooks}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            book.book.title,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (book.book.author != null)
            Text(
              book.book.author!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
        // Banii pot veni și singuri (vânzare), și peste cărți (schimb cu
        // diferență) - de asta nu sunt pe ramura `else`.
        if (payload.amount != null) ...[
          if (book != null) const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.priceLei(payload.amount!.toStringAsFixed(0)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (payload.isEmpty)
          Text(
            '-',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: AppColors.mutedForeground),
          ),
      ],
    );
  }
}
