import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/user.dart';
import '../../../shared/utils/image_upload.dart';

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
    int? birthdayDay,
    int? birthdayMonth,
    List<String>? languages,
    bool? showAcquisitionHistory,
    bool? showAllListingScores,
    bool? hideSwapListingsPublic,
    bool? hideSaleListingsPublic,
    bool? hideDonationListingsPublic,
    bool? hideAuctionListingsPublic,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.patch('/profile/me', data: {
      'name': ?name,
      'username': ?username,
      'nameVisible': ?nameVisible,
      'city': ?city,
      'bio': ?bio,
      'birthdayDay': ?birthdayDay,
      'birthdayMonth': ?birthdayMonth,
      'languages': ?languages,
      'showAcquisitionHistory': ?showAcquisitionHistory,
      'showAllListingScores': ?showAllListingScores,
      'hideSwapListingsPublic': ?hideSwapListingsPublic,
      'hideSaleListingsPublic': ?hideSaleListingsPublic,
      'hideDonationListingsPublic': ?hideDonationListingsPublic,
      'hideAuctionListingsPublic': ?hideAuctionListingsPublic,
    });
    return getMyProfile();
  }

  /// Genurile propuse în chestionar vin de la backend, ca lista să fie una
  /// singură pentru ambele părți (vezi common/constants/book-genres.ts).
  Future<List<String>> getSurveyGenres() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/profile/reading-survey/genres');
    return ((response.data as Map<String, dynamic>)['genres'] as List<dynamic>)
        .cast<String>();
  }

  /// Salvează chestionarul. Apelat și la „sar peste", cu liste goale - backend-ul
  /// marchează oricum chestionarul ca parcurs.
  Future<AppUser> saveReadingSurvey({
    List<String>? favoriteGenres,
    List<String>? favoriteAuthors,
    String? readingPace,
    String? purpose,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.put('/profile/me/reading-survey', data: {
      'favoriteGenres': ?favoriteGenres,
      'favoriteAuthors': ?favoriteAuthors,
      'readingPace': ?readingPace,
      'purpose': ?purpose,
    });
    return getMyProfile();
  }

  /// Încarcă o poză de profil nouă și întoarce profilul reîmprospătat.
  Future<AppUser> uploadProfilePhoto({
    required List<int> bytes,
    required String filename,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final formData = FormData.fromMap({
      'photo': imageMultipartFile(bytes, filename),
    });
    await dio.post('/profile/me/photo', data: formData);
    return getMyProfile();
  }

  Future<AppUser> removeProfilePhoto() async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/profile/me/photo');
    return getMyProfile();
  }

  /// Programează ștergerea contului cu 15 zile grace period. Backend întoarce
  /// `scheduledFor` (ISO date) și `immediate` - `true` doar când backend-ul
  /// rulează cu `INSTANT_ACCOUNT_DELETION=true` (testare locală), caz în care
  /// contul e deja șters definitiv la acest răspuns, nu doar programat. Vezi
  /// AccountDeletionService pe backend.
  Future<({DateTime scheduledFor, bool immediate})> requestAccountDeletion() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/account/delete-request');
    final data = response.data as Map<String, dynamic>;
    return (
      scheduledFor: DateTime.parse(data['scheduledFor'] as String),
      immediate: data['immediate'] == true,
    );
  }

  Future<void> cancelAccountDeletion() async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/account/delete-request');
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

  Future<List<ActivityEvent>> getActivityFeed({int limit = 30, int offset = 0}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/profile/activity-feed',
      queryParameters: {'limit': limit, 'offset': offset},
    );
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
