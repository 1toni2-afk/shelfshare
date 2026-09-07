import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shelfshare/core/analytics/analytics.dart';
import 'package:shelfshare/core/analytics/analytics_backend.dart';

/// Backend de test care doar reține ce a primit. Nu atinge nici gtag, nici
/// Firebase - testele de aici sunt despre CE raportăm la fiecare navigare,
/// nu despre unde ajunge raportul.
class _RecordingBackend implements AnalyticsBackend {
  final screens = <({String location, String routeName})>[];
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> initialize() async {}

  @override
  bool get consentGranted => true;

  @override
  bool get consentAnswered => true;

  @override
  Future<void> setConsent(bool granted) async {}

  @override
  void screenView({required String location, required String routeName}) =>
      screens.add((location: location, routeName: routeName));

  @override
  void event(String name, Map<String, Object> parameters) =>
      events.add((name: name, parameters: parameters));
}

/// Un shell peste rutele autentificate, ca în `app_router.dart`: fără el
/// testul ar trece și cu un `NavigatorObserver` obișnuit, adică n-ar acoperi
/// exact cazul din care s-a născut implementarea curentă.
GoRouter _buildRouter({String? Function(GoRouterState state)? redirect}) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => redirect?.call(state),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const Text('login')),
      ShellRoute(
        builder: (_, _, child) => child,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(path: '/books/:id', builder: (_, _) => const Text('book')),
        ],
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  group('attachAnalyticsToRouter', () {
    testWidgets('raportează ecranul de intrare, nu doar navigările ulterioare',
        (tester) async {
      final backend = _RecordingBackend();
      final router = _buildRouter();
      await _pump(tester, router);

      attachAnalyticsToRouter(router, Analytics(backend));

      expect(backend.screens, hasLength(1));
      expect(backend.screens.single.location, '/');
    });

    testWidgets('trimite tiparul rutei, nu doar calea cu id-ul completat',
        (tester) async {
      final backend = _RecordingBackend();
      final router = _buildRouter();
      await _pump(tester, router);
      attachAnalyticsToRouter(router, Analytics(backend));

      router.go('/books/abc123');
      await tester.pumpAndSettle();

      // Calea reală rămâne disponibilă, dar numele raportat e tiparul: altfel
      // fiecare carte din catalog ar deveni un rând separat în rapoarte.
      expect(backend.screens.last.location, '/books/abc123');
      expect(backend.screens.last.routeName, '/books/:id');
    });

    testWidgets('navigările din interiorul unui ShellRoute sunt raportate',
        (tester) async {
      final backend = _RecordingBackend();
      final router = _buildRouter();
      await _pump(tester, router);
      attachAnalyticsToRouter(router, Analytics(backend));

      router.go('/books/abc123');
      await tester.pumpAndSettle();

      // Regresia pe care o păzește testul: un NavigatorObserver pus pe
      // routerul exterior nu vede navigările de pe navigatorul shell-ului,
      // deci aici ar rămâne un singur ecran raportat - cel de pornire.
      expect(backend.screens, hasLength(2));
    });

    testWidgets('un redirect nu numără destinația de două ori', (tester) async {
      final backend = _RecordingBackend();
      // Exact forma din aplicație: un vizitator nelogat e trimis de pe orice
      // rută spre /login, ceea ce produce mai multe notificări de la router
      // pentru o singură destinație finală.
      final router = _buildRouter(
        redirect: (state) => state.matchedLocation == '/login' ? null : '/login',
      );
      await _pump(tester, router);
      attachAnalyticsToRouter(router, Analytics(backend));

      router.go('/books/abc123');
      await tester.pumpAndSettle();

      expect(backend.screens.map((s) => s.location), ['/login']);
    });
  });

  group('Analytics', () {
    test('nu propagă erorile din backend către apelant', () {
      final analytics = Analytics(_ThrowingBackend());
      // Un ecran nu are voie să se strice pentru că o statistică n-a plecat.
      expect(() => analytics.screenView(location: '/', routeName: '/'),
          returnsNormally);
      expect(() => analytics.event('test'), returnsNormally);
    });
  });
}

class _ThrowingBackend implements AnalyticsBackend {
  @override
  Future<void> initialize() async => throw StateError('nu');
  @override
  bool get consentGranted => true;
  @override
  bool get consentAnswered => true;
  @override
  Future<void> setConsent(bool granted) async => throw StateError('nu');
  @override
  void screenView({required String location, required String routeName}) =>
      throw StateError('nu');
  @override
  void event(String name, Map<String, Object> parameters) => throw StateError('nu');
}
