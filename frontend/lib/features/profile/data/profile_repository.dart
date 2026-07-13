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

  /// Face PATCH și apoi re-citește profilul complet, fiindcă răspunsul PATCH
  /// nu include toate câmpurile (ex. isEmailVerified) - vezi AppUser.fromJson.
  Future<AppUser> updateProfile({String? name, String? city, String? bio}) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.patch('/profile/me', data: {
      'name': ?name,
      'city': ?city,
      'bio': ?bio,
    });
    return getMyProfile();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref);
});
