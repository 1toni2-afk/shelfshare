import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_request.dart';
import '../data/book_requests_repository.dart';

class BookRequestsController extends AsyncNotifier<List<BookRequest>> {
  @override
  Future<List<BookRequest>> build() {
    return ref.read(bookRequestsRepositoryProvider).getMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(bookRequestsRepositoryProvider).getMine(),
    );
  }

  /// Trimite formularul. Când backend-ul găsește cartea pe loc nu se creează
  /// nicio cerere, deci lista rămâne neatinsă - vezi BookRequestResult.
  Future<BookRequestResult> create({
    required String title,
    String? author,
    String? isbn,
    String? note,
  }) async {
    final repository = ref.read(bookRequestsRepositoryProvider);
    final result = await repository.create(
      title: title,
      author: author,
      isbn: isbn,
      note: note,
    );
    final created = result.request;
    if (created != null) {
      final current = state.value ?? const <BookRequest>[];
      state = AsyncData([
        created,
        ...current.where((r) => r.id != created.id),
      ]);
    }
    return result;
  }

  Future<void> cancel(String id) async {
    final repository = ref.read(bookRequestsRepositoryProvider);
    final current = state.value ?? const <BookRequest>[];
    await repository.cancel(id);
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}

final bookRequestsControllerProvider =
    AsyncNotifierProvider<BookRequestsController, List<BookRequest>>(
  BookRequestsController.new,
);
