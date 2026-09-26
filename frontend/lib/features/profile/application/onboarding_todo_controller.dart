import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/onboarding_todo_repository.dart';

/// Pașii din lista „Descoperă ShelfShare" arătată pe Home celor abia veniți.
///
/// Wizard-ul de onboarding (onboarding_flow_screen.dart) întreabă lucruri
/// despre om - gusturi, oraș, scop - și se termină înainte ca el să fi făcut
/// ceva în aplicație. Lista asta e partea cealaltă: ce ARE de făcut ca să
/// pornească, ținută vizibilă până o face sau până o ascunde.
enum OnboardingTodo {
  /// Turul vizual scurt (`/tutorial`).
  tutorial,

  /// O rundă de Book Match, ca să înțeleagă de unde vin recomandările.
  bookMatch,

  /// Importul bibliotecii din Goodreads/StoryGraph sau din șablon.
  import,

  /// Scurtăturile din meniu, puse pe ce folosește el.
  shortcuts,
}

/// Ce s-a bifat până acum și dacă lista a fost ascunsă manual.
class OnboardingTodoState {
  const OnboardingTodoState({
    this.done = const {},
    this.dismissed = false,
    this.loaded = false,
  });

  final Set<OnboardingTodo> done;
  final bool dismissed;

  /// Dacă s-a terminat citirea de pe server. Cât timp e `false` nu știm încă
  /// ce s-a bifat, deci nu arătăm nimic - altfel cineva care a făcut demult
  /// toți pașii ar vedea cardul plin de căsuțe goale la fiecare pornire.
  final bool loaded;

  bool isDone(OnboardingTodo todo) => done.contains(todo);

  bool get allDone => done.length == OnboardingTodo.values.length;

  /// Lista are ce arăta doar dacă știm ce s-a bifat, n-a fost ascunsă și mai
  /// e ceva de făcut.
  bool get visible => loaded && !dismissed && !allDone;

  OnboardingTodoState copyWith({
    Set<OnboardingTodo>? done,
    bool? dismissed,
    bool? loaded,
  }) {
    return OnboardingTodoState(
      done: done ?? this.done,
      dismissed: dismissed ?? this.dismissed,
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Cheile vechi din secure storage, de pe vremea când lista se ținea pe
/// dispozitiv. Rămân doar pentru migrarea unică din [_migrateLegacyLocal]:
/// se citesc o dată, se urcă pe cont și se șterg.
const _legacyDoneKey = 'onboarding_todo_done_v1';
const _legacyDismissedKey = 'onboarding_todo_dismissed_v1';

/// Starea ține de CONT, nu de dispozitiv: pașii descriu ce a făcut omul în
/// aplicație (a văzut turul, și-a importat biblioteca), iar asta nu se uită
/// fiindcă și-a deschis aplicația pe telefon după ce a importat de pe laptop.
///
/// Scrierile sunt trimise și uitate, dar cu reîncercare: bifa apare imediat în
/// UI, iar dacă cererea eșuează pasul rămâne în [_pending] și pleacă odată cu
/// următoarea bifă sau la următoarea pornire.
class OnboardingTodoController extends Notifier<OnboardingTodoState> {
  /// Contul pentru care e starea curentă. `null` = nimeni logat.
  /// Orice răspuns întors pentru alt cont decât ăsta se aruncă - altfel lista
  /// unui user ar rămâne pe ecran după ce se loghează altcineva.
  String? _userId;

  /// Citirea inițială de pe server. Orice modificare o așteaptă (vezi
  /// [_afterLoad]): altfel o bifă pusă înainte ca `_load` să termine era
  /// suprascrisă de valoarea veche o clipă mai târziu - exact cazul „termin
  /// turul, mă întorc pe Home și lista arată tot 0 din 4", fiindcă ecranul
  /// turului e primul care atinge providerul.
  Future<void>? _ready;

  /// Bife făcute, dar neconfirmate încă de server.
  final Set<OnboardingTodo> _pending = {};
  bool _pendingDismiss = false;

  @override
  OnboardingTodoState build() {
    // Providerul trăiește cât aplicația: e citit din ecrane care nu-l
    // afișează (turul, Book Match, scurtăturile), iar fără asta fiecare
    // dintre ele ar crea o instanță nouă, ar porni încă o citire de pe server
    // și ar arunca-o la ieșire - inclusiv bifa tocmai pusă.
    ref.keepAlive();

    // Ascultăm, nu doar citim: la pornire starea de auth e AuthLoading cât se
    // restaurează sesiunea, deci un singur `read` ar vedea „nimeni logat" și
    // n-ar încărca nimic niciodată.
    ref.listen(authControllerProvider, (previous, next) {
      _switchAccount(next is AuthAuthenticated ? next.user.id : null);
    });
    final initial = ref.read(authControllerProvider);
    // Într-un microtask, nu aici: `state` setat sincron în build() e
    // suprascris de valoarea returnată.
    Future.microtask(() {
      _switchAccount(initial is AuthAuthenticated ? initial.user.id : null);
    });

    return const OnboardingTodoState();
  }

  /// Resetează tot și reîncarcă atunci când se schimbă contul (login, logout,
  /// alt user pe același dispozitiv).
  void _switchAccount(String? userId) {
    if (userId == _userId) return;
    final previous = _userId;
    _userId = userId;
    if (previous == null) {
      // Prima dată când aflăm cine e logat. Ce s-a bifat până acum s-a
      // întâmplat în sesiunea asta, deci e al lui: îl păstrăm și îl urcăm pe
      // cont la sfârșitul lui [_load]. Fără asta, un pas bifat în clipa
      // dinaintea restaurării sesiunii (ecranul turului atinge providerul
      // primul) se pierdea aici.
      state = state.copyWith(loaded: false);
    } else {
      // Chiar altcineva: nu-i arătăm bifele userului dinainte.
      _pending.clear();
      _pendingDismiss = false;
      state = const OnboardingTodoState();
    }
    _ready = userId == null ? null : _load();
  }

  Future<void> _load() async {
    final account = _userId;
    try {
      var payload = await ref.read(onboardingTodoRepositoryProvider).get();
      payload = await _migrateLegacyLocal(payload) ?? payload;
      if (_userId != account) return;

      final byName = {for (final todo in OnboardingTodo.values) todo.name: todo};
      state = OnboardingTodoState(
        // Reuniune, nu înlocuire: o bifă pusă cât se citea serverul e la fel
        // de reală ca una salvată de data trecută.
        done: {...payload.done.map((n) => byName[n]).nonNulls, ...state.done},
        dismissed: payload.dismissed || state.dismissed,
        loaded: true,
      );
      unawaited(_flush());
    } catch (_) {
      // O cerere eșuată (offline, server picat) nu trebuie să ascundă lista
      // pentru totdeauna: mergem mai departe cu ce avem în memorie.
      if (_userId != account) return;
      state = state.copyWith(loaded: true);
    }
  }

  /// Migrarea unică de pe dispozitiv pe cont: dacă mai există cheile vechi din
  /// secure storage, le urcăm pe cont și le ștergem. Întoarce starea de după
  /// urcare, sau `null` dacă n-a fost nimic de migrat.
  ///
  /// Se face aici, nu într-un script pe backend, fiindcă bifele vechi au
  /// existat doar pe dispozitiv - serverul n-avea de unde să le știe.
  Future<OnboardingTodoPayload?> _migrateLegacyLocal(
    OnboardingTodoPayload remote,
  ) async {
    try {
      final storage = ref.read(secureStorageProvider);
      final rawDone = await storage.read(key: _legacyDoneKey);
      final rawDismissed = await storage.read(key: _legacyDismissedKey);
      if (rawDone == null && rawDismissed == null) return null;

      final names = {for (final todo in OnboardingTodo.values) todo.name};
      final localDone = (rawDone ?? '')
          .split(',')
          .map((s) => s.trim())
          .where(names.contains)
          .toSet();
      final localDismissed = rawDismissed == '1';

      OnboardingTodoPayload? result;
      final newDone = localDone.difference(remote.done);
      if (newDone.isNotEmpty || (localDismissed && !remote.dismissed)) {
        result = await ref.read(onboardingTodoRepositoryProvider).save(
              done: newDone,
              dismissed: localDismissed ? true : null,
            );
      }
      // Ștergem abia după ce urcarea a reușit - altfel o cădere de rețea ar
      // pierde definitiv bifele vechi.
      await storage.delete(key: _legacyDoneKey);
      await storage.delete(key: _legacyDismissedKey);
      return result;
    } catch (_) {
      // Cheile rămân pe loc, se reîncearcă la următoarea pornire.
      return null;
    }
  }

  /// Rulează [action] după ce citirea inițială s-a terminat, ca modificarea
  /// să se aplice peste starea reală, nu peste cea goală de la pornire.
  void _afterLoad(void Function() action) {
    final ready = _ready;
    if (state.loaded || ready == null) {
      action();
    } else {
      ready.whenComplete(action);
    }
  }

  /// Trimite pe server ce e în așteptare. Ce nu reușește rămâne în [_pending]
  /// și pleacă la următoarea încercare.
  Future<void> _flush() async {
    final account = _userId;
    final steps = {..._pending};
    final dismissed = _pendingDismiss ? true : null;
    if (account == null || (steps.isEmpty && dismissed == null)) return;

    try {
      await ref.read(onboardingTodoRepositoryProvider).save(
            done: steps.map((t) => t.name).toSet(),
            dismissed: dismissed,
          );
      if (_userId != account) return;
      _pending.removeAll(steps);
      if (dismissed != null) _pendingDismiss = false;
    } catch (_) {
      // Best-effort: pasul rămâne bifat în sesiunea curentă și se retrimite.
    }
  }

  /// Bifează un pas. Apelabilă de oriunde s-a întâmplat fapta (o rundă de
  /// Book Match, un import reușit, o scurtătură schimbată) - nu cerem
  /// userului să bifeze el, altfel lista ar minți.
  void complete(OnboardingTodo todo) {
    _afterLoad(() {
      if (state.done.contains(todo)) return;
      state = state.copyWith(done: {...state.done, todo});
      _pending.add(todo);
      unawaited(_flush());
    });
  }

  /// „Ascunde" - lista nu mai apare pe Home, dar bifele rămân.
  void dismiss() {
    _afterLoad(() {
      if (state.dismissed) return;
      state = state.copyWith(dismissed: true);
      _pendingDismiss = true;
      unawaited(_flush());
    });
  }
}

final onboardingTodoProvider =
    NotifierProvider<OnboardingTodoController, OnboardingTodoState>(
  OnboardingTodoController.new,
);
