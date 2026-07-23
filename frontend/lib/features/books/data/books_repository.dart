import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/book.dart';
import '../../../data/models/external_book_result.dart';
import '../../../data/models/map_city.dart';
import '../../../data/models/price_offer.dart';
import '../../../data/models/user_book.dart';

class BrowseResult {
  final List<UserBook> items;
  final int total;

  const BrowseResult({required this.items, required this.total});
}

class ViewStats {
  final int total;
  final int unique;

  const ViewStats({required this.total, required this.unique});

  factory ViewStats.fromJson(Map<String, dynamic> json) {
    return ViewStats(total: json['total'] as int, unique: json['unique'] as int);
  }
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
    String? sort,
    String? fromCity,
    int? maxDistanceKm,
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
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      if (fromCity != null && fromCity.isNotEmpty) 'fromCity': fromCity,
      'maxDistanceKm': ?maxDistanceKm,
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

  Future<ViewStats> getViewStats(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/$id/views');
    return ViewStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ListingHistoryEntry>> getListingHistory(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/$id/history');
    return (response.data as List)
        .map((e) => ListingHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserBook>> getSimilarBooks(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/$id/similar');
    return (response.data as List)
        .map((e) => UserBook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BookGenre>> getGenres({String? query}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/genres', queryParameters: {
      if (query != null && query.isNotEmpty) 'query': query,
    });
    return (response.data as List)
        .map((e) => BookGenre.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getAuthorSuggestions(String query) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/authors', queryParameters: {
      if (query.isNotEmpty) 'query': query,
    });
    return (response.data as List).cast<String>();
  }

  Future<List<String>> getLanguageSuggestions(String query) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/languages', queryParameters: {
      if (query.isNotEmpty) 'query': query,
    });
    return (response.data as List).cast<String>();
  }

  Future<List<BookStatEntry>> getMostSharedBooks() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/most-shared');
    return (response.data as List)
        .map((e) => BookStatEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BookStatEntry>> getTrendingBooks() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/trending');
    return (response.data as List)
        .map((e) => BookStatEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AuthorStatEntry>> getMostPopularAuthors() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/popular-authors');
    return (response.data as List)
        .map((e) => AuthorStatEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SearchStat>> getPopularSearches() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/popular-searches');
    return (response.data as List)
        .map((e) => SearchStat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserBook>> getNearbyToday(String city) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/nearby-today', queryParameters: {'city': city});
    return (response.data as List)
        .map((e) => UserBook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MapCity>> getMapCities() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/books/map-cities');
    return (response.data as List)
        .map((e) => MapCity.fromJson(e as Map<String, dynamic>))
        .toList();
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

  Future<UserBook> relistBook(
    String originalUserBookId, {
    required BookCondition condition,
    String? language,
    String? edition,
    bool isHardcover = false,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/books/$originalUserBookId/relist', data: {
      'condition': condition.toJson(),
      if (language != null && language.isNotEmpty) 'language': language,
      if (edition != null && edition.isNotEmpty) 'edition': edition,
      'isHardcover': isHardcover,
    });
    return UserBook.fromJson(response.data as Map<String, dynamic>);
  }

  /// Trece un anunț la vânzare - separat de creare, pentru că backend-ul
  /// cere cel puțin o poză deja urcată (vezi updateUserBook), iar la
  /// creare nu poate exista încă nicio poză.
  Future<UserBook> markForSale(
    String userBookId, {
    required double salePrice,
    required bool isNegotiable,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.patch('/books/$userBookId', data: {
      'isForSale': true,
      'salePrice': salePrice,
      'isNegotiable': isNegotiable,
    });
    return UserBook.fromJson(response.data as Map<String, dynamic>);
  }

  /// Editare completă a unui anunț deja publicat - condiție, ediție, limbă,
  /// copertă cartonată și, dacă e la vânzare, preț/negociabil. Folosește
  /// același PATCH ca markForSale/setAvailability (backend-ul validează
  /// oricum că există cel puțin o poză înainte de a permite isForSale=true).
  Future<UserBook> updateListing(
    String userBookId, {
    required BookCondition condition,
    String? language,
    String? edition,
    required bool isHardcover,
    required bool isForSale,
    double? salePrice,
    required bool isNegotiable,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.patch('/books/$userBookId', data: {
      'condition': condition.toJson(),
      'language': language,
      'edition': edition,
      'isHardcover': isHardcover,
      'isForSale': isForSale,
      if (isForSale) 'salePrice': salePrice,
      'isNegotiable': isNegotiable,
    });
    return UserBook.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> addPhoto(String userBookId, {required List<int> bytes, required String filename}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: filename.isEmpty ? 'photo.jpg' : filename),
    });
    await dio.post('/books/$userBookId/photos', data: formData);
  }
}

final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  return BooksRepository(ref);
});
