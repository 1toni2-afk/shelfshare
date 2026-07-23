import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/google_callback_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/books/presentation/add_book_screen.dart';
import '../../features/books/presentation/bulk_add_screen.dart';
import '../../features/books/presentation/book_detail_screen.dart';
import '../../features/books/presentation/books_map_screen.dart';
import '../../features/books/presentation/browse_screen.dart';
import '../../features/books/presentation/my_library_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/conversations_list_screen.dart';
import '../../features/exchanges/presentation/exchange_confirm_screen.dart';
import '../../features/exchanges/presentation/exchanges_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/my_profile_screen.dart';
import '../../features/profile/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/following_screen.dart';
import '../../features/books/presentation/global_stats_screen.dart';
import '../../features/books/presentation/my_bookshelf_screen.dart';
import '../../features/profile/presentation/activity_feed_screen.dart';
import '../../features/books/presentation/smart_matches_screen.dart';
import '../../features/books/presentation/auction_detail_screen.dart';
import '../../features/collections/presentation/my_collections_screen.dart';
import '../../features/collections/presentation/collection_detail_screen.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/public_profile_screen.dart';
import '../../features/safety/presentation/help_center_screen.dart';
import '../../features/safety/presentation/safety_center_screen.dart';
import '../../features/wishlist/presentation/wishlist_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

/// Rute accesibile fără autentificare - adaugă aici orice rută nouă care nu
/// trebuie să redirecteze spre /login (ex. un alt provider OAuth, un link
/// de verificare email etc.), fără să atingi logica de redirect de mai jos.
const _publicRoutes = {
  '/login',
  '/register',
  '/forgot-password',
  '/auth/google/callback',
};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Citim starea curentă la fiecare evaluare (nu o captăm o singură
      // dată la construirea routerului) - altfel router-ul s-ar recrea la
      // fiecare schimbare de AuthState și ar folosi o închidere "stale",
      // ceea ce ducea la efectul de "văd pagina principală o clipă, apoi
      // sunt trimis înapoi la login" imediat după autentificare.
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoading = authState is AuthInitial || authState is AuthLoading;
      final goingToAuth = _publicRoutes.contains(state.matchedLocation);
      final goingToOnboarding = state.matchedLocation == '/onboarding';

      if (isLoading) return null; // așteptăm restaurarea sesiunii, fără redirect
      if (!isAuthenticated && !goingToAuth) return '/login';
      if (isAuthenticated && goingToAuth) return '/';
      // Primul login - userul nu și-a ales încă username-ul. Nu blocăm
      // autentificarea, doar restul aplicației până completează.
      if (isAuthenticated &&
          authState.user.username == null &&
          !goingToOnboarding) {
        return '/onboarding';
      }
      if (isAuthenticated &&
          authState.user.username != null &&
          goingToOnboarding) {
        return '/';
      }
      return null;
    },
    refreshListenable: _AuthStateListenable(ref),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/google/callback',
        builder: (context, state) => GoogleCallbackScreen(
          code: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/library/add', builder: (context, state) => const AddBookScreen()),
      GoRoute(path: '/library/bulk-add', builder: (context, state) => const BulkAddScreen()),
      GoRoute(path: '/wishlist', builder: (context, state) => const WishlistScreen()),
      GoRoute(path: '/map', builder: (context, state) => const BooksMapScreen()),
      GoRoute(path: '/exchanges', builder: (context, state) => const ExchangesScreen()),
      GoRoute(
        path: '/exchanges/:id/confirm',
        builder: (context, state) => ExchangeConfirmScreen(exchangeId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(path: '/safety-center', builder: (context, state) => const SafetyCenterScreen()),
      GoRoute(path: '/help-center', builder: (context, state) => const HelpCenterScreen()),
      GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
      GoRoute(path: '/following', builder: (context, state) => const FollowingScreen()),
      GoRoute(path: '/global-stats', builder: (context, state) => const GlobalStatsScreen()),
      GoRoute(path: '/bookshelf', builder: (context, state) => const MyBookshelfScreen()),
      GoRoute(path: '/activity-feed', builder: (context, state) => const ActivityFeedScreen()),
      GoRoute(path: '/smart-matches', builder: (context, state) => const SmartMatchesScreen()),
      GoRoute(
        path: '/auctions/:id',
        builder: (context, state) => AuctionDetailScreen(auctionId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/collections', builder: (context, state) => const MyCollectionsScreen()),
      GoRoute(
        path: '/collections/:id',
        builder: (context, state) => CollectionDetailScreen(
          collectionId: state.pathParameters['id']!,
          ownerId: state.uri.queryParameters['ownerId'],
        ),
      ),
      GoRoute(
        path: '/users/:userId',
        builder: (context, state) => PublicProfileScreen(
          userId: state.pathParameters['userId']!,
          fallback: state.extra as PublicUser?,
        ),
      ),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(
        path: '/books/:userBookId',
        builder: (context, state) => BookDetailScreen(
          userBookId: state.pathParameters['userBookId']!,
          fallbackOwner: state.extra as PublicUser?,
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ConversationScreen(
          conversationId: state.pathParameters['conversationId']!,
          otherUser: state.extra as PublicUser?,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) {
                final args = state.extra as SearchScreenArgs?;
                return BrowseScreen(initialTitle: args?.title, initialGenre: args?.genre);
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/library', builder: (context, state) => const MyLibraryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ConversationsListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const MyProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

/// Adaptor simplu ca GoRouter să reacționeze la schimbările de AuthState
/// din Riverpod (refresh-ul de rute necesită un Listenable clasic).
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
  final Ref _ref;
}
