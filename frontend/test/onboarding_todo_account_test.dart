import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/data/models/user.dart';
import 'package:shelfshare/features/auth/application/auth_controller.dart';
import 'package:shelfshare/features/auth/application/auth_state.dart';
import 'package:shelfshare/features/profile/application/onboarding_todo_controller.dart';
import 'package:shelfshare/features/profile/data/onboarding_todo_repository.dart';

/// Lista „Primii pași" ține de cont, nu de dispozitiv. Ce verificăm aici e
/// exact ce se strică tăcut la o mutare de pe storage local pe server:
/// bifele altui user rămase pe ecran după login, și bifele pierdute fiindcă
/// au fost puse înainte să se termine citirea.
class _FakeRepository implements OnboardingTodoRepository {
  _FakeRepository(this.byAccount, {required this.currentAccount});

  /// Ce „are pe cont" fiecare user, indexat la fel ca în DB.
  final Map<String, Set<String>> byAccount;
  String currentAccount;
  bool dismissed = false;
  int getCount = 0;
  final List<Set<String>> saved = [];

  @override
  Future<OnboardingTodoPayload> get() async {
    getCount++;
    return OnboardingTodoPayload(
      done: {...?byAccount[currentAccount]},
      dismissed: dismissed,
    );
  }

  @override
  Future<OnboardingTodoPayload> save({
    Set<String> done = const {},
    bool? dismissed,
  }) async {
    saved.add(done);
    byAccount.putIfAbsent(currentAccount, () => {}).addAll(done);
    if (dismissed != null) this.dismissed = dismissed;
    return OnboardingTodoPayload(
      done: {...byAccount[currentAccount]!},
      dismissed: this.dismissed,
    );
  }
}

/// AuthController fără repository: `build` e suprascris complet, deci nu
/// atinge rețeaua și nici storage-ul.
class _FakeAuth extends AuthController {
  _FakeAuth(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void signIn(String userId) {
    state = AuthAuthenticated(AppUser(id: userId, email: '$userId@x.ro'));
  }

  void signOut() => state = const AuthUnauthenticated();
}

ProviderContainer _container(_FakeRepository repo, _FakeAuth auth) {
  final container = ProviderContainer(overrides: [
    onboardingTodoRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => auth),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('primii pași pe cont', () {
    test('încarcă de pe server bifele contului logat', () async {
      final repo = _FakeRepository({'u1': {'tutorial'}}, currentAccount: 'u1');
      final auth = _FakeAuth(const AuthLoading());
      final container = _container(repo, auth);
      container.read(onboardingTodoProvider);

      // Cât timp sesiunea se restaurează (AuthLoading) nu e ce încărca.
      await container.pump();
      expect(container.read(onboardingTodoProvider).loaded, isFalse);
      expect(repo.getCount, 0);

      auth.signIn('u1');
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(onboardingTodoProvider);
      expect(state.loaded, isTrue);
      expect(state.isDone(OnboardingTodo.tutorial), isTrue);
      expect(state.isDone(OnboardingTodo.import), isFalse);
    });

    test('o bifă pleacă spre server și rămâne pe cont', () async {
      final repo = _FakeRepository({'u1': <String>{}}, currentAccount: 'u1');
      final auth = _FakeAuth(AuthAuthenticated(AppUser(id: 'u1', email: 'a@x')));
      final container = _container(repo, auth);
      container.read(onboardingTodoProvider);
      await Future<void>.delayed(Duration.zero);

      container
          .read(onboardingTodoProvider.notifier)
          .complete(OnboardingTodo.import);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(onboardingTodoProvider).isDone(OnboardingTodo.import),
          isTrue);
      expect(repo.byAccount['u1'], contains('import'));
    });

    test('o bifă pusă înainte să se termine citirea nu se pierde', () async {
      // Ecranul turului atinge providerul primul: bifa vine în aceeași clipă
      // în care pleacă cererea de citire.
      final repo = _FakeRepository({'u1': <String>{}}, currentAccount: 'u1');
      final auth = _FakeAuth(AuthAuthenticated(AppUser(id: 'u1', email: 'a@x')));
      final container = _container(repo, auth);
      container
          .read(onboardingTodoProvider.notifier)
          .complete(OnboardingTodo.tutorial);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(onboardingTodoProvider).isDone(OnboardingTodo.tutorial),
        isTrue,
      );
      expect(repo.byAccount['u1'], contains('tutorial'));
    });

    test('la schimbarea contului nu rămân bifele userului dinainte', () async {
      final repo = _FakeRepository(
        {'u1': {'tutorial', 'import'}, 'u2': <String>{}},
        currentAccount: 'u1',
      );
      final auth = _FakeAuth(AuthAuthenticated(AppUser(id: 'u1', email: 'a@x')));
      final container = _container(repo, auth);
      container.read(onboardingTodoProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(onboardingTodoProvider).done, hasLength(2));

      repo.currentAccount = 'u2';
      auth.signIn('u2');
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(onboardingTodoProvider).done, isEmpty);
      expect(container.read(onboardingTodoProvider).loaded, isTrue);
    });
  });
}
