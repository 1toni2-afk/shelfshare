import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/user.dart';

class FollowStatus {
  final bool isFollowing;
  final int followersCount;
  final int followingCount;

  const FollowStatus({
    required this.isFollowing,
    required this.followersCount,
    required this.followingCount,
  });

  factory FollowStatus.fromJson(Map<String, dynamic> json) {
    return FollowStatus(
      isFollowing: json['isFollowing'] as bool,
      followersCount: json['followersCount'] as int,
      followingCount: json['followingCount'] as int,
    );
  }
}

class FollowRepository {
  FollowRepository(this._ref);
  final Ref _ref;

  Future<FollowStatus> getStatus(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/users/$userId/follow');
    return FollowStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> follow(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/users/$userId/follow');
  }

  Future<void> unfollow(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/users/$userId/follow');
  }

  Future<List<PublicUser>> getActiveMembers() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/users/active');
    return (response.data as List)
        .map((e) => PublicUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref);
});
