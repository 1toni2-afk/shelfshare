import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/book.dart';

class BookshelfRepository {
  BookshelfRepository(this._ref);
  final Ref _ref;

  Future<Bookshelf> getMyShelf() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me');
    return Bookshelf.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BookshelfStatus?> getStatusForBook(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/bookshelf/me/$bookId');
    final status = response.data['status'] as String?;
    return status != null ? BookshelfStatusX.fromJson(status) : null;
  }

  Future<void> setStatus(String bookId, BookshelfStatus status) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.put('/bookshelf/$bookId', data: {'status': status.toJson()});
  }

  Future<void> removeFromShelf(String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/bookshelf/$bookId');
  }
}

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  return BookshelfRepository(ref);
});
