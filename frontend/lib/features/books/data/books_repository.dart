import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/book.dart';
import '../../../data/models/external_book_result.dart';
import '../../../data/models/user_book.dart';

class BrowseResult {
  final List<UserBook> items;
  final int total;

  const BrowseResult({required this.items, required this.total});
}

class BooksRepository {
  BooksRepository(this._ref);
  final Ref _ref;

  Future<BrowseResult> browse({
    String? title,
    String? author,
    String? genre,
    String? language,
    String? city,
    String? condition,
    int limit = 20,
    int offset = 0,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/browse', queryParameters: {
      if (title != null && title.isNotEmpty) 'title': title,
      if (author != null && author.isNotEmpty) 'author': author,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (language != null && language.isNotEmpty) 'language': language,
      if (city != null && city.isNotEmpty) 'city': city,
      if (condition != null && condition.isNotEmpty) 'condition': condition,
      'limit': limit,
      'offset': offset,
    });

    final items = (response.data['items'] as List<dynamic>)
        .map((e) => UserBook.fromJson(e as Map<String, dynamic>))
        .toList();

    return BrowseResult(items: items, total: response.data['total'] as int);
  }

  Future<UserBook> getUserBook(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/$id');
    return UserBook.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<UserBook>> getMyLibrary() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/my-library');
    return (response.data as List<dynamic>)
        .map((e) => UserBook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserBook> setAvailability(String userBookId, {required bool availableForSwap}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.patch(
      '/books/$userBookId',
      data: {'availableForSwap': availableForSwap},
    );
    return UserBook.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteUserBook(String userBookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/books/$userBookId');
  }

  Future<List<ExternalBookResult>> searchExternal(String query) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/search', queryParameters: {'q': query});
    return (response.data as List<dynamic>)
        .map((e) => ExternalBookResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserBook> addToLibrary({
    String? isbn,
    String? title,
    String? author,
    required BookCondition condition,
    String? language,
    String? edition,
    bool isHardcover = false,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/books', data: {
      if (isbn != null && isbn.isNotEmpty) 'isbn': isbn,
      if (title != null && title.isNotEmpty) 'title': title,
      if (author != null && author.isNotEmpty) 'author': author,
      'condition': condition.toJson(),
      if (language != null && language.isNotEmpty) 'language': language,
      if (edition != null && edition.isNotEmpty) 'edition': edition,
      'isHardcover': isHardcover,
    });
    return UserBook.fromJson(response.data as Map<String, dynamic>);
  }
}

final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  return BooksRepository(ref);
});
