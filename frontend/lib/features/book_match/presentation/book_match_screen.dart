import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/cover_proxy.dart';
import '../../../shared/utils/genre_localization.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../wishlist/application/wishlist_controller.dart';
import '../data/book_match_repository.dart';

/// „Book Match" - un card de carte pe rând, swipe dreapta = da, stânga = nu,
/// sus/buton secundar = skip. Coada vine de la backend în loturi; reîncărcăm
/// din timp (≤ 3 carduri rămase) ca să nu apară un gol de loading între carduri.
class BookMatchScreen extends ConsumerStatefulWidget {
  const BookMatchScreen({super.key, this.embedded = false});

  /// Când e `true`, ecranul renderează doar conținutul (fără Scaffold/AppBar
  /// proprii și fără butonul de recalibrare) - folosit ca pas din wizard-ul
  /// de onboarding, unde Scaffold-ul și header-ul vin de la wizard.
  final bool embedded;

  @override
  ConsumerState<BookMatchScreen> createState() => _BookMatchScreenState();
}

/// Câte carduri cerem per lot și pragul sub care prefetch-uim următorul lot.
const _batchSize = 12;
const _prefetchThreshold = 3;

/// Câte coperte ținem "calde" înainte de cardul curent - doar cardul de sus
/// și următorul erau construite în widget tree (vezi _buildStack), deci
/// coperta cărții #3 nu începea să se descarce decât în momentul în care
/// devenea cardul următor, ceea ce dădea o întârziere vizibilă (~2s) la
/// swipe rapid. precacheImage pornește descărcarea din timp, în afara
/// widget tree-ului, ca prin momentul afișării imaginea să fie deja în
/// cache-ul lui CachedNetworkImage (memorie sau disc).
const _coverPreloadBuffer = 10;

/// Distanța (px) de la care swipe-ul e considerat decis; sub ea, cardul revine.
const _swipeThreshold = 110.0;

enum _SwipeAction {
  yes('YES'),
  no('NO'),
  skip('SKIP');

  const _SwipeAction(this.wire);
  final String wire;
}

class _BookMatchScreenState extends ConsumerState<BookMatchScreen>
    with SingleTickerProviderStateMixin {
  /// Un singur sessionId pentru toată sesiunea de ecran (nu per swipe) - e ce
  /// leagă între ele coada și swipe-urile pentru backend.
  final String _sessionId = generateUuidV4();

  final List<BookMatchCard> _cards = [];

  /// Ce am văzut deja în sesiunea asta - catalogul e mic (~92 cărți), iar
  /// loturile succesive pot repeta titluri; fără dedup, userul le-ar revedea.
  final Set<String> _seenIds = {};

  /// URL-uri de copertă deja trimise la precache - evită re-precache-uirea
  /// aceleiași imagini de fiecare dată când fereastra de buffer avansează.
  final Set<String> _precachedCoverUrls = {};

  bool _initialLoading = true;
  bool _fetching = false;
  bool _exhausted = false;
  Object? _loadError;

  // Starea gestului
  Offset _drag = Offset.zero;
  bool _dragging = false;

  late final AnimationController _animation;
  Animation<Offset>? _flight;
  _SwipeAction? _pendingAction;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addStatusListener(_onAnimationStatus);
    _loadInitial();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  // ---------------- Date ----------------

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _loadError = null;
      _exhausted = false;
    });
    await _fetchBatch();
    if (!mounted) return;
    setState(() => _initialLoading = false);
  }

  Future<void> _fetchBatch() async {
    if (_fetching || _exhausted) return;
    _fetching = true;
    try {
      final queue = await ref
          .read(bookMatchRepositoryProvider)
          .getQueue(sessionId: _sessionId, size: _batchSize);
      if (!mounted) return;
      final fresh = [
        for (final card in queue.cards)
          if (_seenIds.add(card.bookId)) card,
      ];
      setState(() {
        _cards.addAll(fresh);
        // Catalogul e mic: o coadă goală (sau doar duplicate) înseamnă că
        // userul a văzut tot ce aveam - nu mai insistăm cu request-uri.
        if (fresh.isEmpty) _exhausted = true;
        _loadError = null;
      });
      _precacheUpcomingCovers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_cards.isEmpty) _loadError = e;
      });
    } finally {
      _fetching = false;
    }
  }

  void _maybePrefetch() {
    if (_cards.length <= _prefetchThreshold && !_exhausted && !_fetching) {
      _fetchBatch();
    }
  }

  /// Pornește descărcarea coperților pentru primele [_coverPreloadBuffer]
  /// carduri din coadă, ca să fie deja în cache până ajung să fie afișate.
  void _precacheUpcomingCovers() {
    if (!mounted) return;
    for (final card in _cards.take(_coverPreloadBuffer)) {
      final url = coverProxyUrl(card.coverUrl);
      if (url == null || url.isEmpty || !_precachedCoverUrls.add(url)) continue;
      // Eșecul de precache (URL mort, rețea) nu trebuie să crape ecranul -
      // CachedNetworkImage din card mai încearcă oricum la afișare.
      precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
    }
  }

  /// Trimitem swipe-ul „optimist": UI-ul trece deja la cardul următor, iar un
  /// eșec de rețea nu întrerupe fluxul (o singură reîncercare, apoi renunțăm).
  void _recordSwipe(BookMatchCard card, _SwipeAction action) {
    final repository = ref.read(bookMatchRepositoryProvider);
    Future<BookMatchSwipeResult> send() => repository.swipe(
          bookId: card.bookId,
          action: action.wire,
          sessionId: _sessionId,
          isDiscovery: card.isDiscovery,
        );
    // Providerul de wishlist e populat și de alte ecrane (inima de pe
    // carduri), deci poate fi deja în memorie cu lista veche - fără
    // invalidare aici, un „Yes" nu se vede în Wishlist până la un refresh
    // manual sau restart de aplicație.
    void onResult(BookMatchSwipeResult result) {
      if (result.addedToWishlist) {
        ref.invalidate(wishlistControllerProvider);
      }
    }

    send().then(onResult).catchError((_) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        onResult(await send());
      } catch (_) {
        // Un swipe pierdut nu merită un dialog de eroare peste flux.
      }
      return;
    });
  }

  // ---------------- Gest + animație ----------------

  void _onPanStart(DragStartDetails _) {
    if (_animation.isAnimating) return;
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond;
    final decidedRight = _drag.dx > _swipeThreshold || velocity.dx > 700;
    final decidedLeft = _drag.dx < -_swipeThreshold || velocity.dx < -700;
    // Swipe în sus = skip, dar doar dacă mișcarea a fost clar verticală.
    final decidedUp = _drag.dy < -_swipeThreshold && _drag.dx.abs() < _swipeThreshold;

    if (decidedRight) {
      _flyOut(_SwipeAction.yes);
    } else if (decidedLeft) {
      _flyOut(_SwipeAction.no);
    } else if (decidedUp) {
      _flyOut(_SwipeAction.skip);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _pendingAction = null;
    _flight = Tween<Offset>(begin: _drag, end: Offset.zero).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOut),
    );
    _animation.forward(from: 0);
  }

  void _flyOut(_SwipeAction action) {
    if (_cards.isEmpty || _animation.isAnimating) return;
    _dragging = false;
    _pendingAction = action;
    final size = MediaQuery.sizeOf(context);
    final target = switch (action) {
      _SwipeAction.yes => Offset(size.width * 1.4, _drag.dy),
      _SwipeAction.no => Offset(-size.width * 1.4, _drag.dy),
      _SwipeAction.skip => Offset(_drag.dx, -size.height * 1.1),
    };
    _flight = Tween<Offset>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeIn),
    );
    _animation.forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final action = _pendingAction;
    _pendingAction = null;
    _flight = null;
    if (action == null) {
      setState(() => _drag = Offset.zero);
      return;
    }
    final card = _cards.isNotEmpty ? _cards.first : null;
    setState(() {
      if (_cards.isNotEmpty) _cards.removeAt(0);
      _drag = Offset.zero;
    });
    if (card != null) _recordSwipe(card, action);
    _maybePrefetch();
    // Fereastra de 10 avansează cu fiecare swipe - cardul care tocmai a
    // intrat în buffer (fostul #11) nu era precache-uit până acum.
    _precacheUpcomingCovers();
  }

  Offset get _cardOffset => _flight?.value ?? _drag;

  // ---------------- Recalibrare ----------------

  Future<void> _openRecalibrate() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(bookMatchRepositoryProvider);

    BookMatchStatus status;
    try {
      status = await repository.getStatus();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.commonGenericError)));
      return;
    }
    if (!mounted) return;

    if (!status.canRecalibrate) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.bookMatchRecalibrateCooldownTitle),
          content: Text(l10n.bookMatchRecalibrateCooldownBody(status.daysRemaining)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bookMatchRecalibrateTitle),
        content: Text(l10n.bookMatchRecalibrateWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.bookMatchRecalibrateConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repository.recalibrate();
      messenger.showSnackBar(SnackBar(content: Text(l10n.bookMatchRecalibrateDone)));
      // Preferințele s-au schimbat: coada veche nu mai e relevantă.
      _cards.clear();
      _seenIds.clear();
      _exhausted = false;
      await _loadInitial();
    } on RecalibrationCooldownException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookMatchRecalibrateCooldownBody(e.daysRemaining))),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.bookMatchRecalibrateError)));
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return SafeArea(child: Center(child: _buildBody()));
    }
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookMatchTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n.bookMatchRecalibrateTooltip,
            onPressed: _openRecalibrate,
          ),
        ],
      ),
      body: SafeArea(child: Center(child: _buildBody())),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const CircularProgressIndicator();
    }
    if (_cards.isEmpty && _loadError != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: context.l10n.bookMatchLoadError,
        actionLabel: context.l10n.commonRetry,
        onAction: _loadInitial,
      );
    }
    if (_cards.isEmpty) {
      return _MessageState(
        icon: Icons.auto_stories_outlined,
        title: context.l10n.bookMatchEmptyTitle,
        subtitle: context.l10n.bookMatchEmptyBody,
        actionLabel: context.l10n.commonRetry,
        onAction: _loadInitial,
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Expanded(child: _buildStack()),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStack() {
    final next = _cards.length > 1 ? _cards[1] : null;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final offset = _cardOffset;
        final progress = (offset.dx / _swipeThreshold).clamp(-1.0, 1.0);
        final skipProgress = (-offset.dy / _swipeThreshold).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            if (next != null)
              Transform.scale(
                scale: 0.94 + 0.06 * progress.abs(),
                child: Opacity(opacity: 0.6, child: _BookMatchCardView(card: next)),
              ),
            Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: offset.dx / 1400 * math.pi / 4,
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: _BookMatchCardView(
                    card: _cards.first,
                    yesOpacity: progress > 0 ? progress : 0,
                    noOpacity: progress < 0 ? -progress : 0,
                    skipOpacity: offset.dx.abs() < _swipeThreshold ? skipProgress : 0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActions() {
    final l10n = context.l10n;
    final busy = _animation.isAnimating;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Spacer stânga gol - păstrează close+heart centrate, în timp ce
            // Expanded-ul din dreapta împinge butonul de info spre marginea
            // ecranului (nu lipit de inimă, ca să nu fie atins accidental).
            const Expanded(child: SizedBox.shrink()),
            _RoundAction(
              icon: Icons.close,
              color: AppColors.destructive,
              tooltip: l10n.bookMatchNoTooltip,
              onPressed: busy ? null : () => _flyOut(_SwipeAction.no),
            ),
            const SizedBox(width: 28),
            _RoundAction(
              icon: Icons.favorite,
              color: AppColors.success,
              tooltip: l10n.bookMatchYesTooltip,
              onPressed: busy ? null : () => _flyOut(_SwipeAction.yes),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                // Descrierea nu mai încape pe card (vezi _BookMatchCardView) -
                // butonul de info deschide detaliile complete ale cărții
                // curente, fără să aglomereze cardul de swipe.
                child: _RoundAction(
                  icon: Icons.info_outline,
                  color: AppColors.mutedForeground,
                  tooltip: l10n.bookMatchInfoTooltip,
                  onPressed: _cards.isEmpty ? null : () => _showBookInfo(_cards.first),
                ),
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: busy ? null : () => _flyOut(_SwipeAction.skip),
          icon: const Icon(Icons.skip_next, size: 18),
          label: Text(l10n.bookMatchSkip),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.mutedForeground,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.bookMatchHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Detaliile complete ale cărții curente (inclusiv descrierea, scoasă de
  /// pe cardul de swipe - vezi _BookMatchCardView) - deschise din butonul
  /// de info, nu impuse tuturor userilor pe fiecare card.
  Future<void> _showBookInfo(BookMatchCard card) {
    final meta = [
      if (card.genre != null && card.genre!.isNotEmpty) localizedGenre(context, card.genre!),
      if (card.publishedYear != null) '${card.publishedYear}',
    ].join(' · ');
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.title, style: Theme.of(sheetContext).textTheme.titleLarge),
              if (card.author != null && card.author!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  card.author!,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedForeground),
                ),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(meta, style: Theme.of(sheetContext).textTheme.bodySmall),
              ],
              if (card.description != null && card.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(card.description!, style: Theme.of(sheetContext).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          shape: const CircleBorder(),
          color: color.withValues(alpha: 0.12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Cardul propriu-zis: copertă mare + titlu, autor, gen/an - fără descriere,
/// ca userul să decidă rapid din copertă (descrierea completă e disponibilă
/// din butonul de info, vezi [_BookMatchScreenState._showBookInfo]).
/// Ștampilele DA/NU/SKIP apar peste el pe măsură ce userul trage de card.
class _BookMatchCardView extends StatelessWidget {
  const _BookMatchCardView({
    required this.card,
    this.yesOpacity = 0,
    this.noOpacity = 0,
    this.skipOpacity = 0,
  });

  final BookMatchCard card;
  final double yesOpacity;
  final double noOpacity;
  final double skipOpacity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final meta = [
      if (card.genre != null && card.genre!.isNotEmpty) localizedGenre(context, card.genre!),
      if (card.publishedYear != null) '${card.publishedYear}',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: AspectRatio(
                        aspectRatio: 5 / 7,
                        child: BookCover.expand(
                          url: card.coverUrl,
                          title: card.title,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (card.author != null && card.author!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          card.author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(meta, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (card.isDiscovery)
            Positioned(
              top: 12,
              left: 12,
              child: Chip(
                avatar: const Icon(Icons.explore_outlined, size: 16),
                label: Text(l10n.bookMatchDiscoveryBadge),
                visualDensity: VisualDensity.compact,
              ),
            ),
          Positioned(
            top: 20,
            left: 16,
            child: _Stamp(
              text: l10n.bookMatchStampYes,
              color: AppColors.success,
              opacity: yesOpacity,
              angle: -0.32,
            ),
          ),
          Positioned(
            top: 20,
            right: 16,
            child: _Stamp(
              text: l10n.bookMatchStampNo,
              color: AppColors.destructive,
              opacity: noOpacity,
              angle: 0.32,
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _Stamp(
                text: l10n.bookMatchStampSkip,
                color: AppColors.mutedForeground,
                opacity: skipOpacity,
                angle: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.text,
    required this.color,
    required this.opacity,
    required this.angle,
  });

  final String text;
  final Color color;
  final double opacity;
  final double angle;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.01) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.mutedForeground),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
