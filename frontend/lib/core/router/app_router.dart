import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user.dart';
import '../../data/models/price_offer.dart';
import '../../data/models/exchange_request.dart';
import '../../data/models/search_screen_args.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../shared/widgets/main_scaffold.dart';
import 'deferred_screen.dart';

// ---------------------------------------------------------------------------
// Nivelul 0 - intră în bundle-ul inițial
//
// Doar ce trebuie ca un vizitator să vadă și să folosească ecranul de intrare:
// login, înregistrare, resetare parolă, callback-ul Google. Plus shell-ul
// (MainScaffold) și starea de autentificare, de care depinde redirectul.
// ---------------------------------------------------------------------------
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/google_callback_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';

// ---------------------------------------------------------------------------
// Nivelurile 1-3 - încărcate amânat, câte o bibliotecă per nivel
//
// Nivelul 1 se preîncarcă în fundal imediat după primul frame (Home, Discover,
// detaliu carte - unde ajunge userul în marea majoritate a cazurilor după
// login). Nivelul 2 e restul aplicației de zi cu zi, nivelul 3 secțiunile
// rare; ambele se descarcă la prima navigare într-acolo.
//
// Vezi `tiers/tier1.dart` pentru de ce sunt trei barrel-uri și nu un
// `deferred as` per ecran.
// ---------------------------------------------------------------------------
import 'tiers/tier1.dart' deferred as tier1;
import 'tiers/tier2.dart' deferred as tier2;
import 'tiers/tier3.dart' deferred as tier3;

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

/// Pornește descărcarea ecranelor de nivel 1 (Home, Discover, detaliu carte)
/// fără să le afișeze. Se apelează din `main.dart` după primul frame: userul e
/// pe login (sau se restaurează sesiunea), conexiunea e liberă, iar când ajunge
/// pe Home ecranul e deja descărcat, fără indicator de încărcare.
void preloadPrimaryScreens() {
  DeferredScreen.preload(tier1.loadLibrary);
}

/// Chei separate pentru navigator-ele nested - fără ele, `context.pop()` din
/// interiorul unei rute standalone (ex. /wishlist) încearcă să scoată de pe
/// stiva root și ecranul se umple cu blank.
final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Prescurtare pentru o rută al cărei ecran stă într-o bibliotecă amânată.
/// `loader` e mereu `<prefix>.loadLibrary`, iar `builder` construiește ecranul
/// - apelat abia după ce biblioteca s-a încărcat.
GoRoute _deferredRoute(
  String path,
  LibraryLoader loader,
  Widget Function(BuildContext context, GoRouterState state) builder,
) {
  return GoRoute(
    path: path,
    builder: (context, state) => DeferredScreen(
      loader: loader,
      builder: (context) => builder(context, state),
    ),
  );
}

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
      _deferredRoute('/onboarding', tier2.loadLibrary,
          (context, state) => tier2.OnboardingFlowScreen()),

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
                _deferredRoute('/', tier1.loadLibrary,
                    (context, state) => tier1.HomeScreen()),
              ]),
              StatefulShellBranch(routes: [
                _deferredRoute('/search', tier1.loadLibrary,
                    (context, state) => tier1.DiscoverScreen()),
              ]),
              StatefulShellBranch(routes: [
                _deferredRoute('/library', tier2.loadLibrary,
                    (context, state) => tier2.MyLibraryScreen()),
              ]),
              StatefulShellBranch(routes: [
                _deferredRoute('/chat', tier2.loadLibrary,
                    (context, state) => tier2.ConversationsListScreen()),
              ]),
              StatefulShellBranch(routes: [
                _deferredRoute('/profile', tier2.loadLibrary,
                    (context, state) => tier2.MyProfileScreen()),
              ]),
            ],
          ),

          // Rute standalone - toate acestea afișează sidebar-ul din
          // MainScaffold și schimbă doar zona de conținut din dreapta.
          _deferredRoute('/wishlist', tier2.loadLibrary,
              (context, state) => tier2.WishlistScreen()),
          _deferredRoute('/saved-searches', tier3.loadLibrary,
              (context, state) => tier3.SavedSearchesScreen()),
          _deferredRoute('/notifications', tier2.loadLibrary,
              (context, state) => tier2.NotificationsScreen()),
          _deferredRoute('/settings', tier2.loadLibrary,
              (context, state) => tier2.SettingsScreen()),
          _deferredRoute('/profile/edit', tier2.loadLibrary,
              (context, state) => tier2.EditProfileScreen()),
          _deferredRoute('/about-app', tier3.loadLibrary,
              (context, state) => tier3.AboutAppScreen()),
          _deferredRoute('/roadmap', tier3.loadLibrary,
              (context, state) => tier3.RoadmapScreen()),
          _deferredRoute('/library/add', tier2.loadLibrary,
              (context, state) => tier2.AddBookScreen()),
          _deferredRoute('/library/bulk-add', tier3.loadLibrary,
              (context, state) => tier3.BulkAddScreen()),
          _deferredRoute('/library/trash', tier3.loadLibrary,
              (context, state) => tier3.TrashScreen()),
          _deferredRoute('/browse', tier2.loadLibrary, (context, state) {
            final args = state.extra as SearchScreenArgs?;
            return tier2.BrowseScreen(
              initialTitle: args?.title,
              initialAuthor: args?.author,
              initialGenre: args?.genre,
              initialListingType: args?.listingType,
              initialCity: args?.city,
              initialSort: args?.sort,
            );
          }),
          _deferredRoute('/map', tier3.loadLibrary,
              (context, state) => tier3.BooksMapScreen()),
          _deferredRoute('/exchanges', tier3.loadLibrary,
              (context, state) => tier3.ExchangesScreen()),
          _deferredRoute(
            '/exchanges/:id/confirm',
            tier3.loadLibrary,
            (context, state) => tier3.ExchangeConfirmScreen(
              exchangeId: state.pathParameters['id']!,
            ),
          ),
          _deferredRoute(
            '/exchanges/:id/ready',
            tier3.loadLibrary,
            (context, state) => tier3.ReadyToExchangeScreen(
              exchangeId: state.pathParameters['id']!,
              initial: state.extra as ExchangeRequest?,
            ),
          ),
          _deferredRoute(
            '/offers/:id/ready',
            tier3.loadLibrary,
            (context, state) => tier3.ReadyToSellScreen(
              offerId: state.pathParameters['id']!,
              initial: state.extra as PriceOffer?,
            ),
          ),
          _deferredRoute('/admin', tier3.loadLibrary,
              (context, state) => tier3.AdminScreen()),
          _deferredRoute('/admin/users', tier3.loadLibrary,
              (context, state) => tier3.AdminUsersScreen()),
          _deferredRoute('/admin/listings/inactive', tier3.loadLibrary,
              (context, state) => tier3.AdminInactiveListingsScreen()),
          _deferredRoute('/admin/feature-access', tier3.loadLibrary,
              (context, state) => tier3.FeatureAccessScreen()),
          _deferredRoute('/admin/listings/score', tier3.loadLibrary,
              (context, state) => tier3.ListingScoreScreen()),
          _deferredRoute('/admin/administrators', tier3.loadLibrary,
              (context, state) => tier3.AdministratorsScreen()),
          _deferredRoute('/admin/roles', tier3.loadLibrary,
              (context, state) => tier3.RolesPermissionsScreen()),
          _deferredRoute('/admin/chat', tier3.loadLibrary,
              (context, state) => tier3.AdminChatInboxScreen()),
          _deferredRoute(
            '/admin/chat/:id',
            tier3.loadLibrary,
            (context, state) => tier3.AdminChatConversationScreen(
              conversationId: state.pathParameters['id']!,
            ),
          ),
          _deferredRoute('/support/chat', tier3.loadLibrary,
              (context, state) => tier3.AdminChatScreen()),
          _deferredRoute('/pre-register', tier3.loadLibrary,
              (context, state) => tier3.PreRegistrationScreen()),
          _deferredRoute('/leaderboard', tier3.loadLibrary,
              (context, state) => tier3.LeaderboardScreen()),
          _deferredRoute('/following', tier3.loadLibrary,
              (context, state) => tier3.FollowingScreen()),
          _deferredRoute('/global-stats', tier3.loadLibrary,
              (context, state) => tier3.GlobalStatsScreen()),
          _deferredRoute('/bookshelf', tier3.loadLibrary,
              (context, state) => tier3.MyBookshelfScreen()),
          _deferredRoute('/activity-feed', tier3.loadLibrary,
              (context, state) => tier3.ActivityFeedScreen()),
          _deferredRoute('/smart-matches', tier3.loadLibrary,
              (context, state) => tier3.SmartMatchesScreen()),
          _deferredRoute('/book-match', tier2.loadLibrary,
              (context, state) => tier2.BookMatchScreen()),
          _deferredRoute(
            '/auctions/:id',
            tier3.loadLibrary,
            (context, state) => tier3.AuctionDetailScreen(
              auctionId: state.pathParameters['id']!,
            ),
          ),
          _deferredRoute('/collections', tier3.loadLibrary,
              (context, state) => tier3.MyCollectionsScreen()),
          _deferredRoute('/groups', tier3.loadLibrary,
              (context, state) => tier3.GroupsScreen()),
          _deferredRoute('/seller-analytics', tier3.loadLibrary,
              (context, state) => tier3.SellerAnalyticsScreen()),
          _deferredRoute(
            '/groups/:id',
            tier3.loadLibrary,
            (context, state) => tier3.GroupDetailScreen(
              groupId: state.pathParameters['id']!,
            ),
          ),
          _deferredRoute(
            '/collections/:id',
            tier3.loadLibrary,
            (context, state) => tier3.CollectionDetailScreen(
              collectionId: state.pathParameters['id']!,
              ownerId: state.uri.queryParameters['ownerId'],
            ),
          ),
          _deferredRoute(
            '/users/:userId',
            tier2.loadLibrary,
            (context, state) => tier2.PublicProfileScreen(
              userId: state.pathParameters['userId']!,
              fallback: state.extra as PublicUser?,
            ),
          ),
          _deferredRoute(
            '/books/:userBookId',
            tier1.loadLibrary,
            (context, state) => tier1.BookDetailScreen(
              userBookId: state.pathParameters['userBookId']!,
              fallbackOwner: state.extra as PublicUser?,
            ),
          ),
          _deferredRoute(
            '/chat/:conversationId',
            tier2.loadLibrary,
            (context, state) => tier2.ConversationScreen(
              conversationId: state.pathParameters['conversationId']!,
              otherUser: state.extra as PublicUser?,
            ),
          ),
          GoRoute(
            path: '/photo-viewer',
            pageBuilder: (context, state) {
              final (photos, initialIndex) = state.extra as (List<String>, int);
              // PhotoViewerScreen stă în biblioteca detaliului de carte, de
              // unde e deschis oricum - deci în practică e deja încărcată.
              return MaterialPage(
                fullscreenDialog: true,
                child: DeferredScreen(
                  loader: tier1.loadLibrary,
                  builder: (context) => tier1.PhotoViewerScreen(
                    photos: photos,
                    initialIndex: initialIndex,
                  ),
                ),
              );
            },
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
