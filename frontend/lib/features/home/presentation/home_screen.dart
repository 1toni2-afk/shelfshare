import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/typewriter_text.dart';
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
    final name = authState is AuthAuthenticated ? authState.user.name : null;
    final unreadCount =
        (ref.watch(notificationsControllerProvider).value ?? const []).where((n) => !n.isRead).length;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TypewriterText(
          phrases: _greetings(name),
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

  List<TypewriterPhrase> _greetings(String? name) {
    final username = (name != null && name.isNotEmpty) ? name : 'Cititorule';
    return [
      TypewriterPhrase('Salut, $username!', const Duration(seconds: 10)),
      const TypewriterPhrase('Salut, Cititorule!', Duration(seconds: 3)),
      const TypewriterPhrase('Ce mai citești azi?', Duration(seconds: 3)),
      const TypewriterPhrase('Bine ai revenit!', Duration(seconds: 3)),
      const TypewriterPhrase('Gata de-o carte nouă?', Duration(seconds: 3)),
      const TypewriterPhrase('O poveste te așteaptă...', Duration(seconds: 3)),
    ];
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

    // Împărțim recentele în „înainte de carusel" (primele 12) și „după".
    final firstBatch = data.recent.take(_trendingInjectAfter).toList();
    final rest = data.recent.length > _trendingInjectAfter
        ? data.recent.sublist(_trendingInjectAfter)
        : const <UserBook>[];
    final showTrending = data.recent.length >= _trendingInjectAfter && data.mostViewed.isNotEmpty;

    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        _BookSliverGrid(books: firstBatch),
        if (showTrending)
          SliverToBoxAdapter(
            child: _TrendingCarousel(books: data.mostViewed),
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

/// Grilă de 2 coloane. `childAspectRatio` e calibrat ca pe un telefon obișnuit
/// să se vadă ~2 rânduri complete + jumătate din al treilea (cerință Milestone
/// 8), fără overflow pe cardul copertă(2:3) + titlu/autor/locație.
class _BookSliverGrid extends StatelessWidget {
  const _BookSliverGrid({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.54,
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

/// Caruselul orizontal „Cele mai căutate" injectat după primele 12 recente,
/// cu buton „Vezi toate" către Discover.
class _TrendingCarousel extends StatelessWidget {
  const _TrendingCarousel({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeMostSearched,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/search'),
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
