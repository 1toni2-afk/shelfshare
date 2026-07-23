import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/user.dart';

class ProfileRepository {
  ProfileRepository(this._ref);
  final Ref _ref;

  Future<AppUser> getMyProfile() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/me');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PublicUser> getPublicProfile(String userId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/$userId');
    return PublicUser.fromJson(response.data as Map<String, dynamic>);
  }

  /// Face PATCH și apoi re-citește profilul complet, fiindcă răspunsul PATCH
  /// nu include toate câmpurile (ex. isEmailVerified) - vezi AppUser.fromJson.
  Future<AppUser> updateProfile({
    String? name,
    String? username,
    bool? nameVisible,
    String? city,
    String? bio,
    bool? showAcquisitionHistory,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.patch('/profile/me', data: {
      'name': ?name,
      'username': ?username,
      'nameVisible': ?nameVisible,
      'city': ?city,
      'bio': ?bio,
      'showAcquisitionHistory': ?showAcquisitionHistory,
    });
    return getMyProfile();
  }

  Future<List<CityLeaderboardEntry>> getCityLeaderboard() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/leaderboard/cities');
    return (response.data as List)
        .map((e) => CityLeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CityLeaderboardEntry>> getNationalLeaderboard() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/leaderboard/national');
    return (response.data as List)
        .map((e) => CityLeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TopReaderEntry>> getTopReaders() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/leaderboard/top-readers');
    return (response.data as List)
        .map((e) => TopReaderEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MonthlyChallenge>> getMonthlyChallenges() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/monthly-challenges');
    return (response.data as List)
        .map((e) => MonthlyChallenge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReadingChallenge> getReadingChallenge() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/reading-challenge');
    return ReadingChallenge.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReadingChallenge> setReadingChallengeGoal(int? goal) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.patch('/profile/reading-challenge', data: {'goal': goal});
    return ReadingChallenge.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ActivityEvent>> getActivityFeed() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/activity-feed');
    return (response.data as List)
        .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SellerAnalytics> getSellerAnalytics() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/seller-analytics');
    return SellerAnalytics.fromJson(response.data as Map<String, dynamic>);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref);
});
