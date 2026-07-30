import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_grid_metrics.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/typewriter_text.dart';
import 'greetings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../notifications/application/notifications_controller.dart';
import '../application/home_controller.dart';

/// Câte cărți recente afișăm înainte de a injecta caruselul „Cele mai căutate".
const _trendingInjectAfter = 12;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(homeControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final homeAsync = ref.watch(homeControllerProvider);
    final me = authState is AuthAuthenticated ? authState.user : null;
    final unreadCount =
        (ref.watch(notificationsControllerProvider).value ?? const []).where((n) => !n.isRead).length;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: TypewriterText(
          // `DateTime.now()` e ora locală a telefonului, adică exact ce ne
          // trebuie: salutul urmează fusul userului, nu al serverului.
          phrases: buildGreetings(
            l10n: l10n,
            now: DateTime.now(),
            name: me?.name,
            birthdayMonth: me?.birthdayMonth,
            birthdayDay: me?.birthdayDay,
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => context.push('/wishlist'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
          child: homeAsync.when(
            data: (data) => _HomeFeed(
              data: data,
              scrollController: _scrollController,
            ),
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.homeLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(homeControllerProvider.notifier).refresh(),
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _HomeFeed extends StatelessWidget {
  const _HomeFeed({required this.data, required this.scrollController});
  final HomeFeedState data;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (data.recent.isEmpty) {
      return CenteredScrollable(
        child: Text(l10n.homeEmpty, style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    // Trei felii de recente, cu o secțiune tematică între ele: primele 12 →
    // „Cele mai căutate" → următoarele 12 → „În jurul tău" → restul.
    final firstBatch = data.recent.take(_trendingInjectAfter).toList();
    final secondBatch = data.recent.length > _trendingInjectAfter
        ? data.recent.skip(_trendingInjectAfter).take(_trendingInjectAfter).toList()
        : const <UserBook>[];
    final rest = data.recent.length > 2 * _trendingInjectAfter
        ? data.recent.sublist(2 * _trendingInjectAfter)
        : const <UserBook>[];
    final showTrending = data.recent.length >= _trendingInjectAfter && data.mostViewed.isNotEmpty;
    final showNearby = data.nearby.isNotEmpty;

    // Grilă responsivă: cardurile își păstrează lățimea (~220dp), deci pe
    // ecrane înguste ies 2 pe rând, iar pe desktop apar tot mai multe coloane
    // pe măsură ce se lățește fereastra. Plafonat la 1350px (~6 coloane) ca
    // pe monitoare 4K să nu se răsfire pe 10+ coloane.
    //
    // ScrollView-ul ocupă TOATĂ lățimea (chiar dacă vizual conținutul e mai
    // îngust) - altfel wheel-ul de mouse și scroll-ul cu trackpad nu prind pe
    // zonele goale din stânga/dreapta grilei. Constrângerea de lățime e mutată
    // în padding-ul fiecărui sliver, calculat din lățimea ecranului.
    return _buildScrollView(
      context,
      firstBatch,
      secondBatch,
      rest,
      showTrending,
      showNearby,
    );
  }

  Widget _buildScrollView(
    BuildContext context,
    List<UserBook> firstBatch,
    List<UserBook> secondBatch,
    List<UserBook> rest,
    bool showTrending,
    bool showNearby,
  ) {
    final l10n = context.l10n;
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        _BookSliverGrid(books: firstBatch),
        if (showTrending)
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final side = screenWidth > _feedMaxWidth
                    ? (screenWidth - _feedMaxWidth) / 2
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: _TrendingCarousel(books: data.mostViewed),
                );
              },
            ),
          ),
        if (secondBatch.isNotEmpty) _BookSliverGrid(books: secondBatch),
        // „În jurul tău" - cărți disponibile la maxim 50 km de orașul din
        // profil. Ascunsă complet dacă userul nu are oraș setat sau dacă nu e
        // nimic în rază: un carusel gol nu spune nimic.
        if (showNearby)
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final side = screenWidth > _feedMaxWidth
                    ? (screenWidth - _feedMaxWidth) / 2
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: _NearbySection(books: data.nearby),
                );
              },
            ),
          ),
        if (rest.isNotEmpty) _BookSliverGrid(books: rest),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: data.isLoadingMore
                  ? const CircularProgressIndicator()
                  : (data.hasMore ? const SizedBox.shrink() : Text(l10n.homeFeedEnd)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Grilă responsivă. Pe telefon (~360-430dp) iese exact pe 2 coloane, cu ~2
/// rânduri complete + jumătate din al treilea vizibile (cerință Milestone 8).
///
/// Folosim `MaxCrossAxisExtent`, nu `FixedCrossAxisCount`: cu număr fix de
/// coloane, pe web/desktop cele 2 coloane se întindeau pe toată lățimea
/// ferestrei și un singur card ajungea la ~950px. Aici lățimea unui card e
/// plafonată, deci pe ecrane late apar pur și simplu mai multe coloane.
///
/// Metricile cardului stau în book_grid_metrics.dart, ca Raftul meu să
/// folosească exact aceeași grilă.
const _feedMaxWidth = 1350.0;

/// Centrează conținutul lăsând margini egale în stânga/dreapta când ecranul
/// e mai lat decât [_feedMaxWidth] - grila devine „centered" pe monitoare
/// mari, dar ScrollView-ul din jur rămâne pe toată lățimea (ca wheel-ul de
/// mouse să prindă pe orice zonă).
EdgeInsets _centeringPadding(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final extra = screenWidth > _feedMaxWidth ? (screenWidth - _feedMaxWidth) / 2 : 0.0;
  return EdgeInsets.symmetric(horizontal: 16 + extra);
}

class _BookSliverGrid extends StatelessWidget {
  const _BookSliverGrid({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: _centeringPadding(context),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: kBookCardMaxWidth,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: kBookCardAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final userBook = books[index];
            return BookCard(
              userBook: userBook,
              onTap: () => context.push('/books/${userBook.id}', extra: userBook.owner),
            );
          },
          childCount: books.length,
        ),
      ),
    );
  }
}

/// „În jurul tău" - carusel orizontal cu cărțile disponibile la maxim
/// [kNearbyRadiusKm] de orașul userului. Aceeași formă vizuală ca „Cele mai
/// căutate", dar cu iconiță de locație și un accent mai discret, ca să nu
/// concureze cu secțiunea de trending.
class _NearbySection extends StatelessWidget {
  const _NearbySection({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.muted.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Icon(Icons.near_me_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.homeNearbyTitle(kNearbyRadiusKm),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/map'),
                  child: Text(l10n.homeSeeAll),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final userBook = books[index];
                return BookCard(
                  userBook: userBook,
                  width: 150,
                  onTap: () => context.push('/books/${userBook.id}', extra: userBook.owner),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Caruselul orizontal „Cele mai căutate" injectat după primele 12 recente,
/// cu buton „Vezi toate" către Discover.
class _TrendingCarousel extends StatelessWidget {
  const _TrendingCarousel({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Fundal ușor „faded" cu tent de accent, ca secțiunea să se detașeze
    // vizual de grila principală (cerință explicită - fără el, caruselul
    // se pierdea între rândurile de deasupra și dedesubt).
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.accent.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: AppColors.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.homeMostSearched,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.accent,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/browse'),
                  child: Text(l10n.homeSeeAll),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final userBook = books[index];
                return BookCard(
                  userBook: userBook,
                  width: 150,
                  onTap: () => context.push('/books/${userBook.id}', extra: userBook.owner),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
