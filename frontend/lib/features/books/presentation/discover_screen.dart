import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/upcoming_release.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../profile/application/profile_controller.dart';
import '../data/books_repository.dart';
import 'browse_screen.dart';
import 'discover_filter_sheets.dart';

/// Ecranul „Descoperă" - înlocuiește tab-ul vechi de căutare cu un feed de
/// secțiuni curate: genuri (chip-uri), trending, recente, top căutări, cele
/// mai dorite, apariții viitoare. Căutarea propriu-zisă (cu filtre) e mutată
/// pe un ecran separat, accesat prin lupă din AppBar.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSearch),
        actions: [
          // Intrarea în „Book Match" (ecranul de swipe). Stă lângă lupă ca să
          // nu concureze cu bara Filtrează/Sortează din corpul ecranului.
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: l10n.bookMatchEntryTooltip,
            onPressed: () => context.push('/book-match'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.discoverSearchTooltip,
            onPressed: () => context.push('/browse'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Invalidăm toate providerii de secțiuni ca RefreshIndicator să
            // reîmprospăteze întregul ecran, nu doar o secțiune.
            ref.invalidate(discoverGenresProvider);
            ref.invalidate(_trendingProvider);
            ref.invalidate(_popularSearchesProvider);
            ref.invalidate(_mostWishedProvider);
            ref.invalidate(_upcomingProvider);
            ref.invalidate(_recommendedProvider);
            ref.invalidate(_nearYouProvider);
            ref.invalidate(_hiddenGemsProvider);
            ref.invalidate(_popularAuthorsProvider);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: const [
                  // Două butoane, nu o bară de chip-uri: filtrele rapide vechi
                  // („doar schimb" / „licitații" / hartă) acopereau arbitrar
                  // câteva combinații; „Filtrează" + „Sortează" le acoperă pe
                  // toate, cu aceleași taxonomii (gen, tip de anunț).
                  _FilterSortBar(),
                  SizedBox(height: 8),
                  _RecommendedSection(),
                  SizedBox(height: 8),
                  _TrendingSection(),
                  SizedBox(height: 8),
                  _NearYouSection(),
                  SizedBox(height: 8),
                  _MostWishedSection(),
                  SizedBox(height: 8),
                  _HiddenGemsSection(),
                  SizedBox(height: 8),
                  _PopularSearchesSection(),
                  SizedBox(height: 8),
                  _PopularAuthorsSection(),
                  SizedBox(height: 8),
                  _UpcomingSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Provideri per secțiune - fiecare face un singur GET și e invalidabil
// individual de RefreshIndicator.
final _trendingProvider = FutureProvider(
  (ref) => ref.watch(booksRepositoryProvider).getTrendingListings(),
);
final _popularSearchesProvider = FutureProvider(
  (ref) => ref.watch(booksRepositoryProvider).getPopularSearches(),
);
final _mostWishedProvider = FutureProvider(
  (ref) => ref.watch(booksRepositoryProvider).getMostWishedBooks(),
);
final _upcomingProvider = FutureProvider(
  (ref) => ref.watch(adminRepositoryProvider).getUpcomingReleases(),
);
final _recommendedProvider = FutureProvider<List<UserBook>>((ref) async {
  // Necesită auth. Pentru vizitatori întoarcem listă goală, ca secțiunea să
  // dispară complet (nu era rost de „login ca să vezi recomandări" într-un
  // ecran de descoperire deschis oricui).
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthAuthenticated) return const [];
  return ref.watch(booksRepositoryProvider).getRecommendedForYou();
});
final _nearYouProvider = FutureProvider<List<UserBook>>((ref) async {
  final profile = ref.watch(profileControllerProvider).value;
  final city = profile?.city;
  if (city == null || city.isEmpty) return const [];
  return ref.watch(booksRepositoryProvider).getNearbyToday(city);
});
final _hiddenGemsProvider = FutureProvider(
  (ref) => ref.watch(booksRepositoryProvider).getHiddenGems(),
);
final _popularAuthorsProvider = FutureProvider(
  (ref) => ref.watch(booksRepositoryProvider).getMostPopularAuthors(),
);

// ---------------- Secțiuni ----------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon, this.onSeeAll});
  final String title;
  final IconData? icon;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text(context.l10n.homeSeeAll)),
        ],
      ),
    );
  }
}

class _HorizontalCarousel extends StatelessWidget {
  const _HorizontalCarousel({required this.books, this.showScoreBadge = false});
  final List<UserBook> books;

  /// Doar „Cele mai căutate" cere badge-ul, și doar dacă serverul a trimis un
  /// scor (ceea ce face exclusiv pentru admini).
  final bool showScoreBadge;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          context.l10n.homeEmpty,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return SizedBox(
      height: 290,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final ub = books[index];
          final card = BookCard(
            userBook: ub,
            width: 150,
            onTap: () => context.push('/books/${ub.id}', extra: ub.owner),
          );
          final score = ub.searchScore;
          if (!showScoreBadge || score == null) return card;
          return Stack(
            children: [
              card,
              Positioned(top: 6, left: 6, child: _ScoreBadge(score: score)),
            ],
          );
        },
      ),
    );
  }
}

/// „Cele mai căutate" - ordonată de backend după scorul de interes pe 14 zile
/// (view unic 3p, refresh 0.1p, favorite 1p, cu expirare individuală a
/// punctelor). Scorul e invizibil pentru userii normali: backendul îl trimite
/// doar adminilor, iar badge-ul de mai jos apare doar când există.
class _TrendingSection extends ConsumerWidget {
  const _TrendingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_trendingProvider);
    return async.when(
      loading: () => _SkeletonSection(
        title: context.l10n.discoverMostLookedFor,
        icon: Icons.local_fire_department,
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: context.l10n.discoverMostLookedFor,
              icon: Icons.local_fire_department,
            ),
            _HorizontalCarousel(books: books, showScoreBadge: true),
          ],
        );
      },
    );
  }
}

/// Badge de debug cu scorul de interes - vizibil doar adminilor, fiindcă doar
/// lor le trimite backendul `searchScore` (vezi BooksService.getTrendingListings).
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.discoverScoreBadgeTooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          score.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PopularSearchesSection extends ConsumerWidget {
  const _PopularSearchesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_popularSearchesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (searches) {
        if (searches.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: context.l10n.discoverTopSearches,
              icon: Icons.trending_up,
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: searches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _PopularSearchChip(stat: searches[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PopularSearchChip extends StatelessWidget {
  const _PopularSearchChip({required this.stat});
  final SearchStat stat;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(stat.query),
      avatar: Text(
        '${stat.count}',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.mutedForeground),
      ),
      onPressed: () => context.push(
        '/browse',
        extra: SearchScreenArgs(title: stat.query),
      ),
    );
  }
}

class _MostWishedSection extends ConsumerWidget {
  const _MostWishedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_mostWishedProvider);
    return async.when(
      loading: () => _SkeletonSection(
        title: context.l10n.discoverMostWishedFor,
        icon: Icons.favorite_outline,
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: context.l10n.discoverMostWishedFor,
              icon: Icons.favorite_outline,
            ),
            _HorizontalCarousel(books: books),
          ],
        );
      },
    );
  }
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_upcomingProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (releases) {
        if (releases.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: context.l10n.homeUpcomingBooks,
              icon: Icons.event_outlined,
            ),
            for (final r in releases) _UpcomingTile(release: r),
          ],
        );
      },
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.release});
  final UpcomingRelease release;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat('d MMM yyyy', locale).format(release.releaseDate);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: BookCover(url: release.coverUrl, width: 48, height: 68),
      title: Text(release.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (release.author != null) release.author!,
          dateStr,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.event_outlined, color: AppColors.mutedForeground),
    );
  }
}

/// Bara de sus a Discover-ului: „Filtrează" + „Sortează" (Milestone 20).
/// Înlocuiește vechea bară de chip-uri (doar schimb / licitații active /
/// hartă / primele 6 genuri): acele shortcut-uri erau o selecție arbitrară
/// dintr-un spațiu de filtre mult mai mare. Ambele butoane deschid un bottom
/// sheet și, la aplicare, duc rezultatul pe ecranul de căutare - singurul cu
/// paginare și filtre reale.
class _FilterSortBar extends ConsumerWidget {
  const _FilterSortBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_outlined, size: 20),
              label: Text(l10n.discoverFilterButton),
              onPressed: () async {
                final args = await showDiscoverFilterSheet(context);
                if (args != null && context.mounted) {
                  context.push('/browse', extra: args);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.swap_vert, size: 20),
              label: Text(l10n.discoverSortButton),
              onPressed: () async {
                final args = await showDiscoverSortSheet(context);
                if (args != null && context.mounted) {
                  context.push('/browse', extra: args);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedSection extends ConsumerWidget {
  const _RecommendedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_recommendedProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: context.l10n.discoverRecommendedForYou,
              icon: Icons.auto_awesome,
            ),
            _HorizontalCarousel(books: books),
          ],
        );
      },
    );
  }
}

class _NearYouSection extends ConsumerWidget {
  const _NearYouSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_nearYouProvider);
    final profile = ref.watch(profileControllerProvider).value;
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        final city = profile?.city;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: city != null && city.isNotEmpty
                  ? '${context.l10n.discoverNearYou} · $city'
                  : context.l10n.discoverNearYou,
              icon: Icons.place_outlined,
              onSeeAll: city != null && city.isNotEmpty
                  ? () => context.push('/browse', extra: SearchScreenArgs(city: city))
                  : null,
            ),
            _HorizontalCarousel(books: books),
          ],
        );
      },
    );
  }
}

class _HiddenGemsSection extends ConsumerWidget {
  const _HiddenGemsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_hiddenGemsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: context.l10n.discoverHiddenGems,
              icon: Icons.diamond_outlined,
            ),
            _HorizontalCarousel(books: books),
          ],
        );
      },
    );
  }
}

class _PopularAuthorsSection extends ConsumerWidget {
  const _PopularAuthorsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_popularAuthorsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (authors) {
        if (authors.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: context.l10n.discoverPopularAuthors,
              icon: Icons.person_pin_outlined,
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: authors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final a = authors[index];
                  return ActionChip(
                    label: Text('${a.author}  ·  ${a.count}'),
                    onPressed: () => context.push(
                      '/browse',
                      extra: SearchScreenArgs(author: a.author),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Placeholder-e carduri gri afișate cât timp o secțiune se încarcă. Structura
/// e aceeași ca `_HorizontalCarousel`, deci layout-ul nu tresare când datele
/// vin. Preferat față de un spinner central (fost mesaj de „ecran blocat" pe
/// cold start, când backend-ul lua ~1 min să răspundă la primul apel).
class _SkeletonCarousel extends StatelessWidget {
  const _SkeletonCarousel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, _) {
          final placeholder = AppColors.muted;
          return SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 210,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(height: 14, width: 130, color: placeholder),
                const SizedBox(height: 6),
                Container(height: 12, width: 100, color: placeholder),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Placeholder secțiune cu antet + skeleton carousel, pentru secțiunile care
/// pot fi lente sau importante vizual. Fără el, între loading și data,
/// pagina arăta ca un ecran gol și user nu era sigur că se încarcă ceva.
class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection({required this.title, this.icon});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, icon: icon),
        const _SkeletonCarousel(),
      ],
    );
  }
}
