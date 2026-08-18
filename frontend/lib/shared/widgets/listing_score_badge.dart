import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/books/data/books_repository.dart';

/// Cache + batching pentru scorurile de interes afișate ca badge pe
/// cardurile de carte, vizibile DOAR pentru admini (vezi
/// BooksService.getListingScoresForCards pe backend - non-adminii primesc
/// mereu `{}`, deci widget-ul e sigur de folosit necondiționat, indiferent
/// cine se uită).
///
/// Fiecare card cere scorul lui la build - notifier-ul adună id-urile
/// cerute într-o fereastră scurtă și le trimite într-un singur request
/// POST /books/scores, ca un grid de 20 de cărți să nu declanșeze 20 de
/// request-uri separate.
class ListingScoreCache extends Notifier<Map<String, double?>> {
  final Set<String> _pending = {};
  Timer? _debounce;

  @override
  Map<String, double?> build() => const {};

  void request(String userBookId) {
    if (state.containsKey(userBookId) || _pending.contains(userBookId)) return;
    _pending.add(userBookId);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 30), _flush);
  }

  Future<void> _flush() async {
    final ids = _pending.toList();
    _pending.clear();
    if (ids.isEmpty) return;
    try {
      final scores = await ref.read(booksRepositoryProvider).getListingScores(ids);
      state = {
        ...state,
        for (final id in ids) id: scores[id],
      };
    } catch (_) {
      // O eroare de rețea nu trebuie să blocheze cardurile - pur și simplu nu
      // apare badge-ul de data asta; id-urile rămân necache-uite, deci un
      // build ulterior va reîncerca automat.
    }
  }
}

final listingScoreCacheProvider =
    NotifierProvider<ListingScoreCache, Map<String, double?>>(ListingScoreCache.new);

/// Badge cu scorul de interes al anunțului - gândit pentru colțul
/// stânga-sus al cardului de carte. Invizibil pentru useri normali, și
/// pentru admini invizibil pe anunțurile fără scor (fie n-au evenimente
/// recente, fie nu sunt în top - vezi ListingScoreService.scoresForCards).
class ListingScoreBadge extends ConsumerWidget {
  const ListingScoreBadge({super.key, required this.userBookId});
  final String userBookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;
    if (!isAdmin) return const SizedBox.shrink();

    // Cerere la build, nu în initState - un ConsumerWidget nu are state
    // propriu, iar addPostFrameCallback e sigur de apelat din build repetat
    // (request() e idempotent cât timp id-ul e deja cache-uit/în așteptare).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listingScoreCacheProvider.notifier).request(userBookId);
    });

    final score = ref.watch(listingScoreCacheProvider.select((s) => s[userBookId]));
    if (score == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 13, color: Colors.orangeAccent),
          const SizedBox(width: 3),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
