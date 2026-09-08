import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/book_request.dart';

class BookRequestsRepository {
  BookRequestsRepository(this._ref);
  final Ref _ref;

  Future<List<BookRequest>> getMine() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/book-requests/mine');
    return (response.data as List<dynamic>)
        .map((e) => BookRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BookRequestResult> create({
    required String title,
    String? author,
    String? isbn,
    String? note,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/book-requests', data: {
      'title': title,
      if (author != null && author.isNotEmpty) 'author': author,
      if (isbn != null && isbn.isNotEmpty) 'isbn': isbn,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return BookRequestResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> cancel(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/book-requests/$id');
  }
}

final bookRequestsRepositoryProvider = Provider<BookRequestsRepository>((ref) {
  return BookRequestsRepository(ref);
});
