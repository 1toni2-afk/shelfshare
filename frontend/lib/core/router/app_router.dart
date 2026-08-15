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
import '../../features/books/presentation/discover_screen.dart';
import '../../features/books/presentation/trash_screen.dart';
import '../../features/book_match/presentation/book_match_screen.dart';
import '../../features/books/presentation/my_library_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/conversations_list_screen.dart';
import '../../features/exchanges/presentation/exchange_confirm_screen.dart';
import '../../features/exchanges/presentation/exchanges_screen.dart';
import '../../features/exchanges/presentation/ready_to_exchange_screen.dart';
import '../../data/models/exchange_request.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/about_app_screen.dart';
import '../../features/profile/presentation/about_dev_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/my_profile_screen.dart';
import '../../features/profile/presentation/pre_registration_screen.dart';
import '../../features/profile/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/following_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/books/presentation/global_stats_screen.dart';
import '../../features/books/presentation/my_bookshelf_screen.dart';
import '../../features/profile/presentation/activity_feed_screen.dart';
import '../../features/books/presentation/smart_matches_screen.dart';
import '../../features/books/presentation/auction_detail_screen.dart';
import '../../features/collections/presentation/my_collections_screen.dart';
import '../../features/collections/presentation/collection_detail_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/profile/presentation/seller_analytics_screen.dart';
import '../../features/profile/presentation/onboarding_flow_screen.dart';
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

/// Rutele fiecărui branch din tab-uri, în ordinea din sidebar. Folosit atât de
/// router pentru StatefulShellRoute cât și de MainScaffold ca să știe pe ce
/// tab e user-ul curent (bazat pe URL).
const kBranchPaths = ['/', '/search', '/library', '/chat', '/profile'];

/// Chei separate pentru navigator-ele nested - fără ele, `context.pop()` din
/// interiorul unei rute standalone (ex. /wishlist) încearcă să scoată de pe
/// stiva root și ecranul se umple cu blank.
final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    navigatorKey: _rootKey,
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
      // Onboarding-ul e un wizard unic (username + chestionar de cititor +
      // BookMatch + primele cărți, vezi onboarding_flow_screen.dart) - rămânem
      // pe /onboarding cât timp oricare din cele două semnale de completare
      // lipsește, ca userul să nu fie scos din mijlocul wizard-ului. Wizard-ul
      // salvează username-ul imediat la pasul 1, dar restul răspunsurilor abia
      // la final (readingSurveyCompletedAt), deci un refresh la jumătatea
      // wizard-ului reintră direct la pasul de chestionar, nu de la username.
      if (isAuthenticated &&
          (authState.user.username == null ||
              authState.user.readingSurveyCompletedAt == null) &&
          !goingToOnboarding) {
        return '/onboarding';
      }
      if (isAuthenticated &&
          authState.user.username != null &&
          authState.user.readingSurveyCompletedAt != null &&
          goingToOnboarding) {
        return '/';
      }
      return null;
    },
    refreshListenable: _AuthStateListenable(ref),
    routes: [
      // Rutele publice și onboarding rămân la nivel root (NU au sidebar-ul).
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
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingFlowScreen()),

      // ShellRoute exterior - toate rutele autentificate stau înăuntru. Aici
      // se randează MainScaffold cu sidebar-ul. Când user-ul navighează între
      // rute standalone (ex. /wishlist → /notifications), sidebar-ul rămâne
      // vizibil pentru că doar child-ul se schimbă, MainScaffold e stabil.
      ShellRoute(
        parentNavigatorKey: _rootKey,
        navigatorKey: _shellKey,
        builder: (context, state, child) => MainScaffold(
          currentLocation: state.matchedLocation,
          child: child,
        ),
        routes: [
          // Tab-urile propriu-zise. StatefulShellRoute păstrează starea
          // fiecărui branch (scroll position, sub-navigations).
          //
          // Rutele „secundare" (settings, wishlist, notifications etc.) NU mai
          // stau în branch-uri - sunt în afara StatefulShellRoute, la același
          // nivel cu el. Așa, tab-ul curent nu-și mai amintește o vizită la
          // Settings când user-ul se întoarce la Chat (bug-ul cu tab-uri
          // „lipite" pe Settings).
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => navigationShell,
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const DiscoverScreen(),
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
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const MyProfileScreen(),
                ),
              ]),
            ],
          ),

          // Rute standalone - toate acestea afișează sidebar-ul din
          // MainScaffold și schimbă doar zona de conținut din dreapta.
          GoRoute(path: '/wishlist', builder: (context, state) => const WishlistScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
          GoRoute(path: '/about-dev', builder: (context, state) => const AboutDevScreen()),
          GoRoute(path: '/about-app', builder: (context, state) => const AboutAppScreen()),
          GoRoute(path: '/library/add', builder: (context, state) => const AddBookScreen()),
          GoRoute(path: '/library/bulk-add', builder: (context, state) => const BulkAddScreen()),
          GoRoute(path: '/library/trash', builder: (context, state) => const TrashScreen()),
          GoRoute(
            path: '/browse',
            builder: (context, state) {
              final args = state.extra as SearchScreenArgs?;
              return BrowseScreen(
                initialTitle: args?.title,
                initialAuthor: args?.author,
                initialGenre: args?.genre,
                initialListingType: args?.listingType,
                initialCity: args?.city,
              );
            },
          ),
          GoRoute(path: '/map', builder: (context, state) => const BooksMapScreen()),
          GoRoute(path: '/exchanges', builder: (context, state) => const ExchangesScreen()),
          GoRoute(
            path: '/exchanges/:id/confirm',
            builder: (context, state) => ExchangeConfirmScreen(exchangeId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/exchanges/:id/ready',
            builder: (context, state) => ReadyToExchangeScreen(
              exchangeId: state.pathParameters['id']!,
              initial: state.extra as ExchangeRequest?,
            ),
          ),
          GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
          GoRoute(path: '/safety-center', builder: (context, state) => const SafetyCenterScreen()),
          GoRoute(path: '/pre-register', builder: (context, state) => const PreRegistrationScreen()),
          GoRoute(path: '/help-center', builder: (context, state) => const HelpCenterScreen()),
          GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
          GoRoute(path: '/following', builder: (context, state) => const FollowingScreen()),
          GoRoute(path: '/global-stats', builder: (context, state) => const GlobalStatsScreen()),
          GoRoute(path: '/bookshelf', builder: (context, state) => const MyBookshelfScreen()),
          GoRoute(path: '/activity-feed', builder: (context, state) => const ActivityFeedScreen()),
          GoRoute(path: '/smart-matches', builder: (context, state) => const SmartMatchesScreen()),
          GoRoute(path: '/book-match', builder: (context, state) => const BookMatchScreen()),
          GoRoute(
            path: '/auctions/:id',
            builder: (context, state) => AuctionDetailScreen(auctionId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/collections', builder: (context, state) => const MyCollectionsScreen()),
          GoRoute(path: '/groups', builder: (context, state) => const GroupsScreen()),
          GoRoute(path: '/seller-analytics', builder: (context, state) => const SellerAnalyticsScreen()),
          GoRoute(
            path: '/groups/:id',
            builder: (context, state) => GroupDetailScreen(groupId: state.pathParameters['id']!),
          ),
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
