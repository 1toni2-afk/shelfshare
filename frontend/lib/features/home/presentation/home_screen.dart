import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/user_book.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_grid_metrics.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/main_scaffold.dart' show kSidebarBreakpoint;
import '../../../shared/widgets/motto_text.dart';
import '../../../shared/widgets/typewriter_text.dart';
import 'greetings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/presentation/notification_routing.dart';
import '../../exchanges/application/exchanges_controller.dart';
import '../../../data/models/exchange_request.dart';
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
    // Sub 400dp (telefon), o frază lungă nu mai încape pe o linie la
    // titleLarge. În loc s-o tăiem brusc la marginea AppBar-ului, trecem pe
    // font mai mic + 2 linii, cu un AppBar puțin mai înalt ca să le încapă.
    final isNarrow = MediaQuery.of(context).size.width < 400;
    // Sub pragul de sidebar, MainScaffold desenează butonul de meniu plutitor
    // peste colțul stânga-sus al ecranului (vezi main_scaffold.dart). Titlul
    // e `centerTitle` din temă, dar fraza de salut e destul de lungă cât să
    // umple aproape tot slotul disponibil - „centrarea" ei tot începea lipit
    // de marginea stângă, exact sub buton. Un `leading` gol rezervă spațiul
    // ăsta, la fel cum săgeata de back îl rezervă natural pe alte ecrane.
    final needsMenuClearance =
        MediaQuery.of(context).size.width < kSidebarBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: needsMenuClearance ? const SizedBox.shrink() : null,
        leadingWidth: needsMenuClearance ? 64 : null,
        toolbarHeight: isNarrow ? 72 : kToolbarHeight,
        title: TypewriterText(
          // Cheie pe nume: fără ea, widgetul își păstrează starea de animație
          // (poziția de tastare) între rebuild-uri. Când numele userului se
          // încarcă asincron DUPĂ primul cadru (auth mai lent decât Home),
          // fraza nouă (cu numele complet) era citită la un `_charCount` vechi
          // rămas de la fraza inițială (fără nume) - de-aici „Toni Mu_" blocat
          // câteva secunde. O cheie diferită forțează un remount curat, care
          // repornește animația de la zero pe textul corect.
          key: ValueKey(me?.name),
          // `DateTime.now()` e ora locală a telefonului, adică exact ce ne
          // trebuie: salutul urmează fusul userului, nu al serverului.
          phrases: buildGreetings(
            l10n: l10n,
            now: DateTime.now(),
            name: me?.name,
            birthdayMonth: me?.birthdayMonth,
            birthdayDay: me?.birthdayDay,
          ),
          maxLines: isNarrow ? 2 : 1,
          style: (isNarrow
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.bold),
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
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
              child: homeAsync.when(
                data: (data) => _HomeFeed(
                  data: data,
                  scrollController: _scrollController,
                ),
                loading: () => const CenteredScrollable(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      MottoText(),
                    ],
                  ),
                ),
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
          // Bandă care alunecă de la dreapta la stânga, în dreptul
          // clopoțelului, când sosește o notificare nouă (Milestone 23).
          const _NotificationToast(),
        ],
      ),
    );
  }

}

/// Urmărește `notificationsControllerProvider` și arată o bandă scurtă,
/// dinamică, când apare o notificare nouă - dispare singură după câteva
/// secunde sau la tap (care deschide direct notificarea/lista).
class _NotificationToast extends ConsumerStatefulWidget {
  const _NotificationToast();

  @override
  ConsumerState<_NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends ConsumerState<_NotificationToast> {
  Set<String> _seenIds = {};
  bool _initialized = false;
  bool _visible = false;
  String? _message;
  AppNotification? _target;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  static const _replyTypes = {
    NotificationType.exchangeRequestAccepted,
    NotificationType.exchangeRequestRejected,
    NotificationType.priceOfferAccepted,
    NotificationType.priceOfferRejected,
    NotificationType.outbid,
    NotificationType.auctionWon,
    NotificationType.auctionEnded,
  };

  String _labelFor(AppLocalizations l10n, List<AppNotification> fresh) {
    if (fresh.length > 1) return l10n.notificationsToastMultiple;
    final type = fresh.first.type;
    if (type == NotificationType.newMessage) return l10n.notificationsToastNewMessage;
    if (_replyTypes.contains(type)) return l10n.notificationsToastNewReply;
    return l10n.notificationsToastGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    ref.listen(notificationsControllerProvider, (previous, next) {
      final nextList = next.value;
      if (nextList == null) return;
      // Prima emisie de date (încărcarea inițială) nu e o „notificare nouă" -
      // doar stabilim linia de bază față de care comparăm rundele următoare.
      if (!_initialized) {
        _initialized = true;
        _seenIds = nextList.map((n) => n.id).toSet();
        return;
      }
      final fresh = nextList.where((n) => !_seenIds.contains(n.id)).toList();
      _seenIds = nextList.map((n) => n.id).toSet();
      if (fresh.isEmpty) return;

      _hideTimer?.cancel();
      setState(() {
        _message = _labelFor(l10n, fresh);
        _target = fresh.length == 1 ? fresh.first : null;
        _visible = true;
      });
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _visible = false);
      });
    });

    return Positioned(
      top: 0,
      right: 12,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            offset: _visible ? Offset.zero : const Offset(1.3, 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _visible ? 1 : 0,
              child: GestureDetector(
                onTap: () {
                  _hideTimer?.cancel();
                  setState(() => _visible = false);
                  final target = _target;
                  if (target != null) {
                    openNotification(context, ref, target);
                  } else {
                    context.push('/notifications');
                  }
                },
                child: Material(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            _message ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.homeEmpty, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            const MottoText(),
          ],
        ),
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
    final slivers = <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      const SliverToBoxAdapter(child: _PendingSwapBanner()),
    ];
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


/// Banner de acțiune în așteptare - cererile de schimb primite și încă
/// nedecise, sus în feed, înainte de secțiunile de descoperire (Milestone 20).
/// Dispare complet când nu e nimic de decis, nu ocupă spațiu degeaba.
class _PendingSwapBanner extends ConsumerWidget {
  const _PendingSwapBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchanges = ref.watch(exchangesControllerProvider).value;
    final pending = exchanges?.received.where((e) => e.status == ExchangeStatus.pending).length ?? 0;
    final ongoing = [
      ...?exchanges?.received.where((e) => e.status == ExchangeStatus.accepted),
      ...?exchanges?.sent.where((e) => e.status == ExchangeStatus.accepted),
    ];

    if (pending == 0 && ongoing.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final side = screenWidth > _feedMaxWidth ? (screenWidth - _feedMaxWidth) / 2 : 0.0;
    final l10n = context.l10n;
    // Cererile PENDING nedecise au prioritate față de "schimb în desfășurare"
    // - sunt acțiunea mai urgentă (Milestone: Exchange flow v2, punctul 4).
    final (icon, text, destination) = pending > 0
        ? (
            Icons.swap_horiz,
            l10n.homePendingSwapBanner(pending),
            '/exchanges',
          )
        : (
            Icons.handshake_outlined,
            l10n.homeOngoingExchangeBanner,
            ongoing.length == 1 ? '/exchanges/${ongoing.first.id}/ready' : '/exchanges',
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(16 + side, 0, 16 + side, 12),
      child: Material(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(destination),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.accent),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(destination),
                  child: Text(l10n.homePendingSwapReview),
                ),
              ],
            ),
          ),
        ),
      ),
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
