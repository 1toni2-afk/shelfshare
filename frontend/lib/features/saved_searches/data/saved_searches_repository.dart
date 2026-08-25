import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/saved_search.dart';

class SavedSearchesRepository {
  SavedSearchesRepository(this._ref);
  final Ref _ref;

  Future<List<SavedSearch>> getMine() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/saved-searches');
    return (response.data as List<dynamic>)
        .map((e) => SavedSearch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SavedSearch> create({
    required String label,
    String? genre,
    String? city,
    double? maxPrice,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/saved-searches', data: {
      'label': label,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (city != null && city.isNotEmpty) 'city': city,
      'maxPrice': ?maxPrice,
    });
    return SavedSearch.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> remove(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/saved-searches/$id');
  }
}

final savedSearchesRepositoryProvider = Provider<SavedSearchesRepository>((ref) {
  return SavedSearchesRepository(ref);
});
