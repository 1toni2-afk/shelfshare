import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/books/presentation/add_book_screen.dart';
import '../../features/books/presentation/book_detail_screen.dart';
import '../../features/books/presentation/browse_screen.dart';
import '../../features/books/presentation/my_library_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/conversations_list_screen.dart';
import '../../features/exchanges/presentation/exchanges_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/my_profile_screen.dart';
import '../../features/wishlist/presentation/wishlist_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoading = authState is AuthInitial || authState is AuthLoading;
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (isLoading) return null; // așteptăm restaurarea sesiunii, fără redirect
      if (!isAuthenticated && !goingToAuth) return '/login';
      if (isAuthenticated && goingToAuth) return '/';
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
      GoRoute(path: '/library/add', builder: (context, state) => const AddBookScreen()),
      GoRoute(path: '/wishlist', builder: (context, state) => const WishlistScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/exchanges', builder: (context, state) => const ExchangesScreen()),
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
              builder: (context, state) => BrowseScreen(initialTitle: state.extra as String?),
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
