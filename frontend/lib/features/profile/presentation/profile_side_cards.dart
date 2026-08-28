import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../books/data/bookshelf_repository.dart';
import '../../wishlist/application/wishlist_controller.dart';

/// Cardurile din coloana dreaptă a profilului propriu pe desktop (Milestone
/// 17). Fiecare card e o componentă independentă, tratabilă separat: dacă
/// unul dintre providerii de care depinde nu are date, se afișează stare
/// goală, restul rămân neatinse.
///
/// Pe mobil, coloana asta nu apare deloc - profilul rămâne single-column,
/// vezi `_ProfileContent` din my_profile_screen.dart.

/// Lățimea coloanei laterale pe desktop. Împreună cu maxWidth-ul coloanei
/// centrale (kProfileContentMaxWidth = 560), suma dă un profil confortabil
/// pentru 1200-1400 px, exact ce am folosit la mockup.
const kProfileSideColumnWidth = 340.0;

/// Ecran mai lat de-atât înseamnă „desktop" - sub, cădem înapoi la
/// single-column. 900 e pragul standard din material și evită șiruri lungi
/// și înguste pe tabletă în orientare portrait.
const kProfileDesktopBreakpoint = 900.0;

class ProfileSideColumn extends ConsumerWidget {
  const ProfileSideColumn({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      children: [
        _AboutCard(user: user),
        const SizedBox(height: 16),
        _InfoCard(user: user),
        const SizedBox(height: 16),
        _StatsGrid(user: user),
        const SizedBox(height: 16),
        _TopGenresCard(readingStats: user.readingStats),
      ],
    );
  }
}

/// „Despre mine" - bio-ul userului plus buton de edit care duce direct în
/// ecranul complet de editare a profilului. Nu facem editare inline într-un
/// dialog: bio-ul e un singur câmp, dar userul care apasă „edit" vrea de
/// obicei să corecteze și altceva.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bio = user.bio?.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.profileAboutMe,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: l10n.profileEditProfile,
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
            if (bio == null || bio.isEmpty)
              Text(
                l10n.profileAboutEmpty,
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  bio,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// „Membru din / Locație / Limbi" - metadate stabile ale contului. Când
/// vreo linie n-are date, se ascunde (nu afișăm „Locație: —" gol).
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.createdAt != null)
              _row(
                context,
                icon: Icons.calendar_today_outlined,
                label: l10n.profileMemberSince,
                // Format „MMM yyyy" localizat, ex. „ian. 2026". Suficient
                // pentru precizia de „membru din <lună>".
                value: DateFormat.yMMM(locale).format(user.createdAt!),
              ),
            if (user.createdAt != null &&
                (user.city != null && user.city!.isNotEmpty ||
                    user.languages.isNotEmpty))
              const SizedBox(height: 14),
            if (user.city != null && user.city!.isNotEmpty)
              _row(
                context,
                icon: Icons.location_on_outlined,
                label: l10n.profileLocation,
                value: '${user.city}, ${l10n.countryRomania}',
              ),
            if (user.city != null &&
                user.city!.isNotEmpty &&
                user.languages.isNotEmpty)
              const SizedBox(height: 14),
            if (user.languages.isNotEmpty)
              _row(
                context,
                icon: Icons.language_outlined,
                label: l10n.profileLanguages,
                value: user.languages.join(', '),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.mutedForeground),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grid 2x2 cu cele 4 stat-uri principale ale userului. Cărți citite vine
/// din raftul public (`finished`), Cărți dorite din wishlist - restul sunt
/// pe user direct. Când vreo valoare încă se încarcă, arată 0 (nu spinner
/// per casetă - ar face card-ul să sară vizual).
class _StatsGrid extends ConsumerWidget {
  const _StatsGrid({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final finishedCount = ref
            .watch(myBookshelfProvider)
            .value
            ?.finished
            .length ??
        0;
    // Numărăm TITLURI, nu rânduri: favoritele sunt legate de anunț, deci
    // aceeași carte poate apărea de mai multe ori pe listă.
    final wishlistCount = (ref.watch(wishlistControllerProvider).value ?? const [])
        .map((item) => item.book.id)
        .toSet()
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileStatsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _tile(context, finishedCount, l10n.profileStatBooksRead)),
                const SizedBox(width: 12),
                Expanded(
                    child: _tile(
                        context, user.booksExchangedCount, l10n.profileStatSwaps)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _tile(
                        context, user.booksSharedCount, l10n.profileStatBooksShared)),
                const SizedBox(width: 12),
                Expanded(child: _tile(context, wishlistCount, l10n.profileStatWishlisted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, int value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// „Top genuri" - primele 3 genuri din raftul propriu, ordonate după număr.
/// Când `readingStats` lipsește sau `topGenres` e gol, arată empty state
/// (nu ascundem cardul: userul trebuie să vadă că poate „umple" secțiunea).
class _TopGenresCard extends StatelessWidget {
  const _TopGenresCard({required this.readingStats});
  final ReadingStats? readingStats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final genres = readingStats?.topGenres.take(3).toList() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileTopGenresTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 14),
            if (genres.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined,
                      size: 32, color: AppColors.mutedForeground),
                  const SizedBox(height: 6),
                  Text(
                    l10n.profileTopGenresEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                  ),
                ],
              )
            else
              Column(
                children: [
                  for (final entry in genres)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.genre,
                              style: TextStyle(
                                color: AppColors.foreground,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.count}',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
