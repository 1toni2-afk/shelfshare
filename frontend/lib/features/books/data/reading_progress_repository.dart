import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/reading_progress.dart';

class ReadingProgressRepository {
  ReadingProgressRepository(this._ref);
  final Ref _ref;

  Future<List<ReadingProgress>> getMine() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/reading-progress');
    return (response.data as List)
        .map((e) => ReadingProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReadingProgress> setProgress(String bookId, int currentPage) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.put('/reading-progress/$bookId', data: {'currentPage': currentPage});
    return ReadingProgress.fromJson(response.data as Map<String, dynamic>);
  }
}

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository(ref);
});

final myReadingProgressProvider = FutureProvider<List<ReadingProgress>>((ref) {
  return ref.watch(readingProgressRepositoryProvider).getMine();
});
