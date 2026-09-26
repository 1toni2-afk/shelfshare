import { lazy, Suspense, type ComponentType, type ReactNode } from 'react';
import { createBrowserRouter, Navigate, useLocation } from 'react-router-dom';
import { AppShell } from '@/components/layout/AppShell';
import { FullScreenLoader } from '@/components/ui';
import { useAuth } from '@/features/auth/AuthProvider';
import { RouteErrorScreen, ScreenErrorBoundary } from './ErrorScreen';
import { NotPortedYet } from './NotPortedYet';

/**
 * Cheia sub care ținem minte că am reîncărcat deja pagina pentru un fragment
 * lipsă. Fără ea, un fragment care chiar lipsește (nu din cauza unui deploy)
 * ar trimite tabul într-o buclă de reîncărcări.
 */
const CHUNK_RELOAD_FLAG = 'ss:chunk-reloaded';

/** sessionStorage aruncă în navigare privată; acolo renunțăm la protecție. */
function flag(action: 'get' | 'set' | 'clear'): boolean {
  try {
    if (action === 'get') return sessionStorage.getItem(CHUNK_RELOAD_FLAG) === '1';
    if (action === 'set') sessionStorage.setItem(CHUNK_RELOAD_FLAG, '1');
    else sessionStorage.removeItem(CHUNK_RELOAD_FLAG);
  } catch {
    /* fără sessionStorage nu putem ține minte; mai bine fără decât deloc. */
  }
  return false;
}

/**
 * Încarcă un ecran amânat, cu o reîncărcare de salvare.
 *
 * „Failed to fetch dynamically imported module" nu e o eroare de rețea: e un
 * deploy nou. Tabul deschis are index.html-ul VECHI, care cere fragmente cu
 * hash-ul vechi în nume, iar acele fișiere nu mai există pe server. Omul vede
 * un ecran roșu de eroare la prima navigare de după publicare - exact ce s-a
 * întâmplat la butonul de import din „Cărțile mele".
 *
 * Nu putem reîncerca același URL, fiindcă fișierul chiar a dispărut. Singura
 * reparație e să luăm index.html nou, adică o reîncărcare - o singură dată,
 * altfel un fragment lipsă de-adevăratelea ar bucla.
 */
// `any` ca în semnătura lui React.lazy: ecranele n-au props, dar constrângerea
// trebuie să fie la fel de largă, altfel tipul nu se potrivește.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function lazyScreen<T extends ComponentType<any>>(load: () => Promise<{ default: T }>) {
  return lazy(() =>
    load().then(
      (module) => {
        flag('clear');
        return module;
      },
      (error: unknown) => {
        if (flag('get')) throw error;
        flag('set');
        window.location.reload();
        // Nu rezolvăm niciodată: pagina se reîncarcă, iar un ecran de eroare
        // care apare pentru o fracțiune de secundă înainte e doar zgomot.
        return new Promise<{ default: T }>(() => {});
      },
    ),
  );
}

// Ecranele grele se încarcă la cerere. Echivalentul „tiers"-elor de import
// amânat din app_router.dart, doar că aici împărțirea o face Vite singur, pe
// baza `import()`-ului - nu trebuie grupate manual în barrel-uri ca să nu
// explodeze numărul de fragmente.
const LoginScreen = lazyScreen(() =>
  import('@/features/auth/LoginScreen').then((m) => ({ default: m.LoginScreen })),
);
const HomeScreen = lazyScreen(() =>
  import('@/features/home/HomeScreen').then((m) => ({ default: m.HomeScreen })),
);
const PublicLandingScreen = lazyScreen(() =>
  import('@/features/public/PublicLandingScreen').then((m) => ({ default: m.PublicLandingScreen })),
);
const BookDetailScreen = lazyScreen(() =>
  import('@/features/books/BookDetailScreen').then((m) => ({ default: m.BookDetailScreen })),
);
const RegisterScreen = lazyScreen(() =>
  import('@/features/auth/RegisterScreen').then((m) => ({ default: m.RegisterScreen })),
);
const VerifyEmailScreen = lazyScreen(() =>
  import('@/features/auth/VerifyEmailScreen').then((m) => ({ default: m.VerifyEmailScreen })),
);
const ForgotPasswordScreen = lazyScreen(() =>
  import('@/features/auth/ForgotPasswordScreen').then((m) => ({ default: m.ForgotPasswordScreen })),
);
const GoogleCallbackScreen = lazyScreen(() =>
  import('@/features/auth/GoogleCallbackScreen').then((m) => ({ default: m.GoogleCallbackScreen })),
);
const DiscoverScreen = lazyScreen(() =>
  import('@/features/books/DiscoverScreen').then((m) => ({ default: m.DiscoverScreen })),
);
const BrowseScreen = lazyScreen(() =>
  import('@/features/books/BrowseScreen').then((m) => ({ default: m.BrowseScreen })),
);
const MyLibraryScreen = lazyScreen(() =>
  import('@/features/books/MyLibraryScreen').then((m) => ({ default: m.MyLibraryScreen })),
);
const ConversationsListScreen = lazyScreen(() =>
  import('@/features/chat/ConversationsListScreen').then((m) => ({ default: m.ConversationsListScreen })),
);
const ConversationScreen = lazyScreen(() =>
  import('@/features/chat/ConversationScreen').then((m) => ({ default: m.ConversationScreen })),
);
const NotificationsScreen = lazyScreen(() =>
  import('@/features/notifications/NotificationsScreen').then((m) => ({ default: m.NotificationsScreen })),
);
const MyProfileScreen = lazyScreen(() =>
  import('@/features/profile/MyProfileScreen').then((m) => ({ default: m.MyProfileScreen })),
);
const EditProfileScreen = lazyScreen(() =>
  import('@/features/profile/EditProfileScreen').then((m) => ({ default: m.EditProfileScreen })),
);
const PublicProfileScreen = lazyScreen(() =>
  import('@/features/profile/PublicProfileScreen').then((m) => ({ default: m.PublicProfileScreen })),
);
const SettingsScreen = lazyScreen(() =>
  import('@/features/profile/SettingsScreen').then((m) => ({ default: m.SettingsScreen })),
);
const FollowingScreen = lazyScreen(() =>
  import('@/features/profile/FollowingScreen').then((m) => ({ default: m.FollowingScreen })),
);
const ActivityFeedScreen = lazyScreen(() =>
  import('@/features/profile/ActivityFeedScreen').then((m) => ({ default: m.ActivityFeedScreen })),
);
const WishlistScreen = lazyScreen(() =>
  import('@/features/lists/WishlistScreen').then((m) => ({ default: m.WishlistScreen })),
);
const CollectionsScreen = lazyScreen(() =>
  import('@/features/lists/CollectionsScreen').then((m) => ({ default: m.CollectionsScreen })),
);
const CollectionDetailScreen = lazyScreen(() =>
  import('@/features/lists/CollectionDetailScreen').then((m) => ({ default: m.CollectionDetailScreen })),
);
const SavedSearchesScreen = lazyScreen(() =>
  import('@/features/lists/SavedSearchesScreen').then((m) => ({ default: m.SavedSearchesScreen })),
);
const TrashScreen = lazyScreen(() =>
  import('@/features/lists/TrashScreen').then((m) => ({ default: m.TrashScreen })),
);
const ExchangesScreen = lazyScreen(() =>
  import('@/features/exchanges/ExchangesScreen').then((m) => ({ default: m.ExchangesScreen })),
);
const ReadyToExchangeScreen = lazyScreen(() =>
  import('@/features/exchanges/ReadyToExchangeScreen').then((m) => ({ default: m.ReadyToExchangeScreen })),
);
const LeaderboardScreen = lazyScreen(() =>
  import('@/features/social/LeaderboardScreen').then((m) => ({ default: m.LeaderboardScreen })),
);
const GlobalStatsScreen = lazyScreen(() =>
  import('@/features/social/GlobalStatsScreen').then((m) => ({ default: m.GlobalStatsScreen })),
);
const GroupsScreen = lazyScreen(() =>
  import('@/features/social/GroupsScreen').then((m) => ({ default: m.GroupsScreen })),
);
const GroupDetailScreen = lazyScreen(() =>
  import('@/features/social/GroupDetailScreen').then((m) => ({ default: m.GroupDetailScreen })),
);
const SmartMatchesScreen = lazyScreen(() =>
  import('@/features/social/SmartMatchesScreen').then((m) => ({ default: m.SmartMatchesScreen })),
);
const BookMatchScreen = lazyScreen(() =>
  import('@/features/social/BookMatchScreen').then((m) => ({ default: m.BookMatchScreen })),
);
const BookshelfScreen = lazyScreen(() =>
  import('@/features/shelf/BookshelfScreen').then((m) => ({ default: m.BookshelfScreen })),
);
const BookRequestsScreen = lazyScreen(() =>
  import('@/features/shelf/BookRequestsScreen').then((m) => ({ default: m.BookRequestsScreen })),
);
const FeedbackScreen = lazyScreen(() =>
  import('@/features/shelf/FeedbackScreen').then((m) => ({ default: m.FeedbackScreen })),
);
const BookWorkScreen = lazyScreen(() =>
  import('@/features/work/BookWorkScreen').then((m) => ({ default: m.BookWorkScreen })),
);
const AuctionDetailScreen = lazyScreen(() =>
  import('@/features/work/AuctionDetailScreen').then((m) => ({ default: m.AuctionDetailScreen })),
);
const BooksMapScreen = lazyScreen(() =>
  import('@/features/work/BooksMapScreen').then((m) => ({ default: m.BooksMapScreen })),
);
const AboutAppScreen = lazyScreen(() =>
  import('@/features/info/InfoScreens').then((m) => ({ default: m.AboutAppScreen })),
);
const RoadmapScreen = lazyScreen(() =>
  import('@/features/info/InfoScreens').then((m) => ({ default: m.RoadmapScreen })),
);
const TutorialScreen = lazyScreen(() =>
  import('@/features/info/InfoScreens').then((m) => ({ default: m.TutorialScreen })),
);
const SellerAnalyticsScreen = lazyScreen(() =>
  import('@/features/info/InfoScreens').then((m) => ({ default: m.SellerAnalyticsScreen })),
);
const SupportChatScreen = lazyScreen(() =>
  import('@/features/admin/SupportChatScreen').then((m) => ({ default: m.SupportChatScreen })),
);
const AdminScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminScreen })),
);
const AdminUsersScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminUsersScreen })),
);
const AdminReportsScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminReportsScreen })),
);
const AdminUsageScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminUsageScreen })),
);
const AdminInactiveListingsScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminInactiveListingsScreen })),
);
const AdministratorsScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdministratorsScreen })),
);
const AdminRolesScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminRolesScreen })),
);
const AdminFeatureAccessScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminFeatureAccessScreen })),
);
const AdminChatInboxScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminChatInboxScreen })),
);
const AdminChatConversationScreen = lazyScreen(() =>
  import('@/features/admin/AdminScreens').then((m) => ({ default: m.AdminChatConversationScreen })),
);
const AdminBookRequestsScreen = lazyScreen(() =>
  import('@/features/admin/AdminBookRequestsScreen').then((m) => ({
    default: m.AdminBookRequestsScreen,
  })),
);
const AdminStoresScreen = lazyScreen(() =>
  import('@/features/admin/AdminStoresScreen').then((m) => ({ default: m.AdminStoresScreen })),
);
const AdminListingScoreScreen = lazyScreen(() =>
  import('@/features/admin/AdminListingScoreScreen').then((m) => ({
    default: m.AdminListingScoreScreen,
  })),
);
const StaticPageScreen = lazyScreen(() =>
  import('@/features/info/StaticPageScreen').then((m) => ({ default: m.StaticPageScreen })),
);
const AddBookScreen = lazyScreen(() =>
  import('@/features/books/AddBookScreen').then((m) => ({ default: m.AddBookScreen })),
);
const BulkAddScreen = lazyScreen(() =>
  import('@/features/books/BulkAddScreen').then((m) => ({ default: m.BulkAddScreen })),
);
const ImportScreen = lazyScreen(() =>
  import('@/features/books/ImportScreen').then((m) => ({ default: m.ImportScreen })),
);
const ExchangeConfirmScreen = lazyScreen(() =>
  import('@/features/exchanges/ExchangeConfirmScreen').then((m) => ({ default: m.ExchangeConfirmScreen })),
);
const OnboardingScreen = lazyScreen(() =>
  import('@/features/profile/OnboardingScreens').then((m) => ({ default: m.OnboardingScreen })),
);
const PreRegistrationScreen = lazyScreen(() =>
  import('@/features/profile/OnboardingScreens').then((m) => ({ default: m.PreRegistrationScreen })),
);

/**
 * Gardian pentru rutele autentificate.
 *
 * `restoring` NU redirecționează - afișează ecranul de încărcare. Dacă l-am
 * trata ca „neautentificat", fiecare reîncărcare de pagină ar arunca un user
 * logat pe /login înainte ca /profile/me să apuce să răspundă, iar un link
 * direct către o rută protejată (bookmark, link din email, push) s-ar pierde
 * definitiv.
 */
function RequireAuth({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const location = useLocation();

  if (status.kind === 'restoring') return <FullScreenLoader />;
  if (status.kind !== 'authenticated') {
    // Reținem unde voia să ajungă, ca login-ul să-l trimită înapoi acolo.
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  }

  const redirect = onboardingRedirect(status.user, location.pathname);
  return redirect ?? children;
}

/**
 * Onboardingul, portat din `redirect`-ul din app_router.dart.
 *
 * Regula lipsea complet aici: ecranul `/onboarding` exista, dar nimic nu
 * trimitea pe nimeni la el, deci un cont nou ateriza direct pe pagina
 * principală și nu-și alegea niciodată username-ul.
 *
 * Rămânem pe wizard cât timp lipsește ORICARE dintre cele două semnale:
 * username-ul se salvează la pasul 1, iar chestionarul abia la final. Așa, un
 * refresh la jumătate reintră la pasul de chestionar, nu de la început.
 *
 * Extras din `RequireAuth` ca să-l poată folosi și `PublicOrAppShell`: un cont
 * nou care aterizează pe o rută publică (link din Google către o carte) tot
 * trebuie dus la wizard, altfel ar ocoli onboardingul complet doar fiindcă a
 * intrat pe altă ușă.
 */
function onboardingRedirect(
  user: { username: string | null; readingSurveyCompletedAt: string | null },
  pathname: string,
): ReactNode | null {
  const onOnboarding = pathname === '/onboarding';
  const finished = user.username !== null && user.readingSurveyCompletedAt !== null;

  if (!finished && !onOnboarding) return <Navigate to="/onboarding" replace />;
  // Wizard deja terminat: nu-l mai lăsăm să reintre pe la spate.
  if (finished && onOnboarding) return <Navigate to="/" replace />;
  return null;
}

/**
 * Rutele PUBLICE: aceeași adresă arată conținut și fără cont.
 *
 * ACELAȘI shell pentru amândoi. Vizitatorul avea până acum un antet-subsol
 * separat (`PublicShell`), deci interfața se schimba complet în secunda de
 * după înregistrare - alt meniu, alt aranjament, alt loc pentru fiecare lucru.
 * Acum vede bara laterală obișnuită, iar diferența e doar ce se întâmplă la
 * click: `GuestGateProvider` din AppShell oprește tot ce nu e pagina
 * principală și cere un cont (vezi features/auth/GuestGate.tsx).
 *
 * Fără ramura asta, tot ce ține de conținut ar sta în spatele lui
 * `RequireAuth`, deci orice vizitator - inclusiv un crawler - ar fi trimis la
 * /login și n-ar vedea niciodată catalogul, o carte sau un profil.
 *
 * `restoring` afișează încărcătorul, din același motiv ca în `RequireAuth`:
 * tratată ca „neautentificat", sesiunea încă necitită i-ar arăta unui user
 * logat, pentru o clipă, interfața de vizitator.
 */
function PublicOrAppShell() {
  const { status } = useAuth();
  const location = useLocation();

  if (status.kind === 'restoring') return <FullScreenLoader />;
  if (status.kind !== 'authenticated') return <AppShell />;

  const redirect = onboardingRedirect(status.user, location.pathname);
  return redirect ?? <AppShell />;
}

/**
 * „/" arată lucruri diferite după cum ai cont sau nu: panoul personal pentru
 * userul logat (neschimbat), pagina de prezentare pentru vizitator.
 *
 * Nu e o redirecționare, ci același URL cu două ecrane - adresa canonică a
 * paginii de prezentare rămâne „/", nu una separată care ar împărți semnalele
 * de căutare în două.
 */
function HomeOrLanding() {
  const { user } = useAuth();
  return user ? <HomeScreen /> : <PublicLandingScreen />;
}

function Screen({ children }: { children: ReactNode }) {
  return (
    <ScreenErrorBoundary>
      <Suspense fallback={<FullScreenLoader />}>{children}</Suspense>
    </ScreenErrorBoundary>
  );
}

export const router = createBrowserRouter([
  {
    errorElement: <RouteErrorScreen />,
    path: '/login',
    element: (
      <Screen>
        <LoginScreen />
      </Screen>
    ),
  },
  {
    errorElement: <RouteErrorScreen />,
    path: '/register',
    element: (
      <Screen>
        <RegisterScreen />
      </Screen>
    ),
  },
  {
    errorElement: <RouteErrorScreen />,
    path: '/forgot-password',
    element: (
      <Screen>
        <ForgotPasswordScreen />
      </Screen>
    ),
  },
  {
    errorElement: <RouteErrorScreen />,
    /*
      Confirmarea contului are rută proprie, PUBLICĂ: se ajunge aici și după
      înregistrare, și din ecranul de autentificare când contul există dar nu e
      confirmat. Vezi VerifyEmailScreen pentru de ce nu mai e doar o stare
      locală a ecranului de înregistrare.
    */
    path: '/verify-email',
    element: (
      <Screen>
        <VerifyEmailScreen />
      </Screen>
    ),
  },
  {
    errorElement: <RouteErrorScreen />,
    path: '/auth/google/callback',
    element: (
      <Screen>
        <GoogleCallbackScreen />
      </Screen>
    ),
  },
  {
    errorElement: <RouteErrorScreen />,
    path: '/pre-register',
    element: (
      <Screen>
        <PreRegistrationScreen />
      </Screen>
    ),
  },

  {
    errorElement: <RouteErrorScreen />,
    element: (
      <RequireAuth>
        <AppShell />
      </RequireAuth>
    ),
    children: [
      {
        path: 'search',
        element: (
          <Screen>
            <DiscoverScreen />
          </Screen>
        ),
      },
      {
        path: 'library',
        element: (
          <Screen>
            <MyLibraryScreen />
          </Screen>
        ),
      },
      {
        path: 'chat',
        element: (
          <Screen>
            <ConversationsListScreen />
          </Screen>
        ),
      },
      {
        path: 'chat/:conversationId',
        element: (
          <Screen>
            <ConversationScreen />
          </Screen>
        ),
      },
      {
        path: 'notifications',
        element: (
          <Screen>
            <NotificationsScreen />
          </Screen>
        ),
      },
      { path: 'profile', element: <Screen><MyProfileScreen /></Screen> },
      { path: 'profile/edit', element: <Screen><EditProfileScreen /></Screen> },
      { path: 'settings', element: <Screen><SettingsScreen /></Screen> },
      { path: 'following', element: <Screen><FollowingScreen /></Screen> },
      { path: 'activity-feed', element: <Screen><ActivityFeedScreen /></Screen> },
      { path: 'wishlist', element: <Screen><WishlistScreen /></Screen> },
      { path: 'collections', element: <Screen><CollectionsScreen /></Screen> },
      { path: 'collections/:id', element: <Screen><CollectionDetailScreen /></Screen> },
      { path: 'saved-searches', element: <Screen><SavedSearchesScreen /></Screen> },
      { path: 'library/trash', element: <Screen><TrashScreen /></Screen> },
      { path: 'exchanges', element: <Screen><ExchangesScreen /></Screen> },
      {
        path: 'exchanges/:id/ready',
        element: <Screen><ReadyToExchangeScreen kind="exchange" /></Screen>,
      },
      {
        path: 'offers/:id/ready',
        element: <Screen><ReadyToExchangeScreen kind="offer" /></Screen>,
      },
      { path: 'groups', element: <Screen><GroupsScreen /></Screen> },
      { path: 'smart-matches', element: <Screen><SmartMatchesScreen /></Screen> },
      { path: 'book-match', element: <Screen><BookMatchScreen /></Screen> },
      { path: 'bookshelf', element: <Screen><BookshelfScreen /></Screen> },
      { path: 'book-requests', element: <Screen><BookRequestsScreen /></Screen> },
      { path: 'feedback', element: <Screen><FeedbackScreen /></Screen> },
      { path: 'work/:bookId', element: <Screen><BookWorkScreen /></Screen> },
      { path: 'auctions/:id', element: <Screen><AuctionDetailScreen /></Screen> },
      { path: 'map', element: <Screen><BooksMapScreen /></Screen> },
      { path: 'about-app', element: <Screen><AboutAppScreen /></Screen> },
      { path: 'roadmap', element: <Screen><RoadmapScreen /></Screen> },
      { path: 'tutorial', element: <Screen><TutorialScreen /></Screen> },
      /*
        Paginile publice, deschise ÎN aplicație. Adresele publice (`/privacy`,
        `/safety-center`, ...) rămân servite de beta-server.js pentru Google și
        Play Console; astea sunt doar o a doua fereastră spre același text.
      */
      { path: 'info/:page', element: <Screen><StaticPageScreen /></Screen> },
      { path: 'seller-analytics', element: <Screen><SellerAnalyticsScreen /></Screen> },
      { path: 'support/chat', element: <Screen><SupportChatScreen /></Screen> },

      { path: 'admin', element: <Screen><AdminScreen /></Screen> },
      { path: 'admin/users', element: <Screen><AdminUsersScreen /></Screen> },
      { path: 'admin/reports', element: <Screen><AdminReportsScreen /></Screen> },
      { path: 'admin/usage', element: <Screen><AdminUsageScreen /></Screen> },
      { path: 'admin/listings/inactive', element: <Screen><AdminInactiveListingsScreen /></Screen> },
      { path: 'admin/administrators', element: <Screen><AdministratorsScreen /></Screen> },
      { path: 'admin/roles', element: <Screen><AdminRolesScreen /></Screen> },
      { path: 'admin/feature-access', element: <Screen><AdminFeatureAccessScreen /></Screen> },
      { path: 'admin/chat', element: <Screen><AdminChatInboxScreen /></Screen> },
      { path: 'admin/chat/:id', element: <Screen><AdminChatConversationScreen /></Screen> },
      { path: 'admin/book-requests', element: <Screen><AdminBookRequestsScreen /></Screen> },
      { path: 'admin/stores', element: <Screen><AdminStoresScreen /></Screen> },
      { path: 'admin/listings/score', element: <Screen><AdminListingScoreScreen /></Screen> },
      { path: 'library/add', element: <Screen><AddBookScreen /></Screen> },
      { path: 'library/bulk-add', element: <Screen><BulkAddScreen /></Screen> },
      { path: 'import', element: <Screen><ImportScreen /></Screen> },
      { path: 'onboarding', element: <Screen><OnboardingScreen /></Screen> },
      { path: 'exchanges/:id/confirm', element: <Screen><ExchangeConfirmScreen /></Screen> },
    ],
  },

  /*
    Rutele PUBLICE.

    Stau într-un arbore separat, nu printre cele de mai sus, fiindcă au alt
    gardian: `PublicOrAppShell` lasă vizitatorul să intre, în loc să-l trimită
    la /login. Ecranele sunt aceleași - doar rama din jur diferă, după cum ai
    cont sau nu.

    Toate se sprijină pe endpointuri fără gardian în backend (`GET
    /books/browse`, `/books/:id` cu OptionalJwt, `/profile/:userId`,
    `/groups/:id` cu OptionalJwt, `/profile/leaderboard/*`), deci nu expun
    nimic ce nu era deja public la nivel de API. Ce rămâne după autentificare
    rămâne acolo: mesajele, emailul, telefonul, schimburile, biblioteca
    personală, adminul.

    Aceeași listă e oglindită în scripts/beta-server.js (PUBLIC_ROUTES), care
    le pre-randează conținutul pentru crawlere și le pune în sitemap.
  */
  {
    errorElement: <RouteErrorScreen />,
    element: <PublicOrAppShell />,
    children: [
      { index: true, element: <Screen><HomeOrLanding /></Screen> },
      { path: 'browse', element: <Screen><BrowseScreen /></Screen> },
      { path: 'books/:userBookId', element: <Screen><BookDetailScreen /></Screen> },
      { path: 'users/:userId', element: <Screen><PublicProfileScreen /></Screen> },
      { path: 'groups/:id', element: <Screen><GroupDetailScreen /></Screen> },
      { path: 'leaderboard', element: <Screen><LeaderboardScreen /></Screen> },
      { path: 'global-stats', element: <Screen><GlobalStatsScreen /></Screen> },
    ],
  },

  { path: '*', element: <NotPortedYet notFound />, errorElement: <RouteErrorScreen /> },
]);
