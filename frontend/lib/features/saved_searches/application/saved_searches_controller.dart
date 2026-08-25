import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/saved_search.dart';
import '../data/saved_searches_repository.dart';

class SavedSearchesController extends AsyncNotifier<List<SavedSearch>> {
  @override
  Future<List<SavedSearch>> build() {
    return ref.read(savedSearchesRepositoryProvider).getMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(savedSearchesRepositoryProvider).getMine());
  }

  Future<void> create({
    required String label,
    String? genre,
    String? city,
    double? maxPrice,
  }) async {
    final repository = ref.read(savedSearchesRepositoryProvider);
    final current = state.value ?? const [];
    final created = await repository.create(label: label, genre: genre, city: city, maxPrice: maxPrice);
    state = AsyncData([created, ...current]);
  }

  Future<void> remove(String id) async {
    final repository = ref.read(savedSearchesRepositoryProvider);
    final current = state.value ?? const [];
    await repository.remove(id);
    state = AsyncData(current.where((s) => s.id != id).toList());
  }
}

final savedSearchesControllerProvider = AsyncNotifierProvider<SavedSearchesController, List<SavedSearch>>(
  SavedSearchesController.new,
);
