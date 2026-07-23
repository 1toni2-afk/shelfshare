import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/group.dart';

class GroupsRepository {
  GroupsRepository(this._ref);
  final Ref _ref;

  Future<BookGroup> create(String name, {String? description, bool isPublic = true}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/groups', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'isPublic': isPublic,
    });
    return BookGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BookGroup>> getPublicGroups() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/groups/public');
    return (response.data as List).map((e) => BookGroup.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BookGroup>> getMine() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/groups/mine');
    return (response.data as List).map((e) => BookGroup.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BookGroup> getOne(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/groups/$id');
    return BookGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BookGroup> join(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/groups/$id/join');
    return BookGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> leave(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/groups/$id/leave');
  }

  Future<void> delete(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/groups/$id');
  }

  Future<BookGroup> createPost(String id, String content) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/groups/$id/posts', data: {'content': content});
    return BookGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BookGroup> createEvent(
    String id, {
    required String title,
    String? description,
    required DateTime eventAt,
    String? location,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/groups/$id/events', data: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'eventAt': eventAt.toIso8601String(),
      if (location != null && location.isNotEmpty) 'location': location,
    });
    return BookGroup.fromJson(response.data as Map<String, dynamic>);
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref);
});
