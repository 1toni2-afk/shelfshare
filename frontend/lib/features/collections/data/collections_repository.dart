import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/collection.dart';

class CollectionsRepository {
  CollectionsRepository(this._ref);
  final Ref _ref;

  Future<BookCollection> create(String name, {String? description, bool isPublic = true}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/collections', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'isPublic': isPublic,
    });
    return BookCollection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BookCollection>> getMine() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/collections/mine');
    return (response.data as List).map((e) => BookCollection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BookCollection>> getForUser(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/collections/user/$userId');
    return (response.data as List).map((e) => BookCollection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BookCollection> getOne(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/collections/$id');
    return BookCollection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BookCollection> update(String id, {String? name, String? description, bool? isPublic}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.patch('/collections/$id', data: {
      'name': ?name,
      'description': ?description,
      'isPublic': ?isPublic,
    });
    return BookCollection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/collections/$id');
  }

  Future<BookCollection> addBook(String collectionId, String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/collections/$collectionId/items', data: {'bookId': bookId});
    return BookCollection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeBook(String collectionId, String bookId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/collections/$collectionId/items/$bookId');
  }
}

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  return CollectionsRepository(ref);
});
