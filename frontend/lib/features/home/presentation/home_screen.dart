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

/// Metricile grilei sunt aceleași ca ale delegate-ului (vezi [_BookSliverGrid]).
/// Calculăm coloanele reale din lățimea disponibilă, ca „N rânduri" să însemne
/// N rânduri afișate - nu un număr fix de cărți: pe desktop 3 rânduri = 15
/// cărți, pe telefon aceleași 3 rânduri = 6 cărți.
///
/// Trebuie tratată explicit lățimea infinită: `LayoutBuilder` poate cere o
/// pasă de măsurare cu constraint neconstrans (ex. în interior de
/// `RefreshIndicator`), iar `infinity.floor()` aruncă `UnsupportedError` -
/// care în release ascunde tot ecranul.
int _computeColumns(double availableWidth) {
  if (!availableWidth.isFinite || availableWidth <= 0) return 2;
  const spacing = 16.0;
  final n = ((availableWidth + spacing) / (kBookCardMaxWidth + spacing)).floor();
  return n.clamp(2, 8);
}

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

    // Numărul de coloane și felierea în rânduri se calculează din lățimea
    // ecranului: pe desktop cu 5 coloane, [2, 3, 3] înseamnă 10, 15, 15 cărți
    // între secțiuni; pe telefon cu 2 coloane, aceleași rânduri = 4, 6, 6.
    // Folosim MediaQuery, nu LayoutBuilder - LayoutBuilder poate cere o pasă
    // de măsurare cu constraint infinit când e wrap-uit în RefreshIndicator,
    // ceea ce forța _computeColumns cu infinity și rupea tot ecranul în
    // release. Lățimea ecranului e ce ne trebuia de fapt.
    final horizontalPadding = _centeringPadding(context).horizontal;
    final gridWidth = MediaQuery.of(context).size.width - horizontalPadding;
    final columns = _computeColumns(gridWidth);
    return _buildScrollView(context, columns);
  }

  /// Construiește lista de slivers alternând grile de recente cu secțiunile
  /// tematice care au conținut. O secțiune fără date se sare cu totul, iar
  /// slot-ul ei nu mai consumă rânduri - feed-ul continuă neîntrerupt.
  Widget _buildScrollView(BuildContext context, int columns) {
    final l10n = context.l10n;
    // Definim în ordine secțiunile candidate, cu câte rânduri să le preceadă
    // și cu widget-ul pe care îl injectăm în locul lor. Cele goale se filtrează
    // înainte să atribuim slot-urile - astfel „recomandate" ajunge la locul 2
    // dacă „nearby" e gol, în loc să lase un gol vizual.
    final sections = <_SectionSpec>[
      if (data.mostViewed.isNotEmpty)
        _SectionSpec(
          builder: (_) => _HomeSection(
            title: l10n.homeMostSearched,
            icon: Icons.local_fire_department,
            accent: AppColors.accent,
            books: data.mostViewed,
            seeAllRoute: '/browse',
          ),
        ),
      if (data.nearby.isNotEmpty)
        _SectionSpec(
          builder: (_) => _HomeSection(
            title: l10n.homeNearbyTitle(kNearbyRadiusKm),
            icon: Icons.near_me_outlined,
            accent: AppColors.primary,
            books: data.nearby,
            seeAllRoute: '/map',
          ),
        ),
      if (data.recommended.isNotEmpty)
        _SectionSpec(
          builder: (_) => _HomeSection(
            title: l10n.homeRecommendedTitle,
            icon: Icons.auto_awesome_outlined,
            accent: AppColors.accent,
            books: data.recommended,
            seeAllRoute: '/smart-matches',
          ),
        ),
    ];

    // Cum împărțim feed-ul: `kHomeSectionSlots` = [2, 3, 3] rânduri, deci
    // primele două rânduri → secțiunea 0, următoarele trei → secțiunea 1 etc.
    // Convertim rândurile în număr de cărți folosind numărul de coloane.
    final slivers = <Widget>[const SliverToBoxAdapter(child: SizedBox(height: 12))];
    var cursor = 0;
    for (var i = 0; i < sections.length; i++) {
      final rows = i < kHomeSectionSlots.length ? kHomeSectionSlots[i] : kHomeSectionSlots.last;
      final take = (rows * columns).clamp(0, data.recent.length - cursor);
      if (take > 0) {
        slivers.add(_BookSliverGrid(books: data.recent.sublist(cursor, cursor + take)));
        cursor += take;
      }
      slivers.add(SliverToBoxAdapter(child: sections[i].builder(context)));
    }
    if (cursor < data.recent.length) {
      slivers.add(_BookSliverGrid(books: data.recent.sublist(cursor)));
    }
    slivers.add(
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
    );

    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }
}

/// Ce inserăm între felii de „recent". Wrapper minimalist ca lista din
/// [_HomeFeed._buildScrollView] să rămână citibilă.
class _SectionSpec {
  const _SectionSpec({required this.builder});
  final WidgetBuilder builder;
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

/// Bloc tematic pe Home - fundal decupat cu accent, un titlu cu iconiță, un
/// carusel orizontal de coperți și un buton „vezi toate". Same shape pentru
/// toate cele trei secțiuni („Most Sought After", „Close Near You",
/// „Recommended"), doar culoarea de accent și iconița diferă.
class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.books,
    required this.seeAllRoute,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<UserBook> books;
  final String seeAllRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Fundalul e o benzii care traversează întreaga lățime a ScrollView-ului
    // (ca hardcode-ul de dinainte de refactor) - încadrarea vizuală vine
    // exact de aici, nu din spațiul dintre grile. Padding orizontal se
    // aplică pe titlu și pe listă, nu pe fundal.
    final screenWidth = MediaQuery.of(context).size.width;
    final side = screenWidth > _feedMaxWidth ? (screenWidth - _feedMaxWidth) / 2 : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: accent.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: accent),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(seeAllRoute),
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
      ),
    );
  }
}
