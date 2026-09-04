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

/// O coloană a târgului.
///
/// Cărțile curg de sus în jos (copertă, titlu, autor), fiindcă au trei rânduri
/// de conținut. O parte care e DOAR bani are un singur lucru de arătat, așa că
/// se centrează pe verticală, la înălțimea săgeții dintre coloane, și se scrie
/// mare: lipită de marginea de sus, lângă o copertă de 78, sumă mică arăta ca
/// o notă de subsol, nu ca jumătatea celuilalt om din târg.
class _Side extends StatelessWidget {
  const _Side({required this.label, required this.payload});

  final String label;
  final DealPayload payload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final book = payload.books.isNotEmpty ? payload.books.first : null;
    final amount = payload.amount;
    final amountText =
        amount == null ? null : l10n.priceLei(amount.toStringAsFixed(0));

    final Widget body;
    if (book == null) {
      // Doar bani (sau nimic): un singur bloc, centrat pe toată înălțimea
      // rândului - `Expanded` funcționează fiindcă părintele e IntrinsicHeight.
      body = Expanded(
        child: Center(
          child: Align(
            alignment: Alignment.centerLeft,
            child: amountText == null
                ? Text(
                    '-',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppColors.mutedForeground),
                  )
                : _Amount(text: amountText, big: true),
          ),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // Schimb cu diferență în bani: suma stă sub carte, mai discretă -
          // aici cartea e lucrul principal, banii doar completează.
          if (amountText != null) ...[
            const SizedBox(height: 6),
            _Amount(text: amountText, big: false),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}

/// Suma, cu bancnota lângă ea. `big` o duce de la „detaliu sub o carte" la
/// „ce primești/dai, punct".
class _Amount extends StatelessWidget {
  const _Amount({required this.text, required this.big});

  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.payments_outlined,
          size: big ? 26 : 18,
          color: AppColors.accent,
        ),
        SizedBox(width: big ? 10 : 6),
        Flexible(
          child: Text(
            text,
            // Pornim MEREU de la titleMedium, nu de la headlineSmall: în tema
            // aplicației, tot ce e headline*/title-large e Playfair Display,
            // fontul serif de titlu. Un preț scris cu el ar ieși din familia
            // în care sunt scrise toate celelalte prețuri (DM Sans), deci
            // creștem doar corpul literei.
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: big ? 26 : null,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
