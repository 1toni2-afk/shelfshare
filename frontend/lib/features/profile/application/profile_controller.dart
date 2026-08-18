import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';

class ProfileController extends AsyncNotifier<AppUser> {
  @override
  Future<AppUser> build() {
    return ref.read(profileRepositoryProvider).getMyProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).getMyProfile());
  }

  Future<void> updateProfile({
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
  }) async {
    final updated = await ref.read(profileRepositoryProvider).updateProfile(
          name: name,
          username: username,
          nameVisible: nameVisible,
          city: city,
          bio: bio,
          birthdayDay: birthdayDay,
          birthdayMonth: birthdayMonth,
          languages: languages,
          showAcquisitionHistory: showAcquisitionHistory,
          showAllListingScores: showAllListingScores,
        );
    state = AsyncData(updated);
    ref.read(authControllerProvider.notifier).setUser(updated);
  }

  /// Salvează chestionarul de cititor. `authController` trebuie actualizat și
  /// el: routerul decide pe baza lui dacă mai afișează chestionarul, deci fără
  /// asta userul ar rămâne blocat pe ecranul de survey după ce l-a trimis.
  Future<void> saveReadingSurvey({
    List<String>? favoriteGenres,
    List<String>? favoriteAuthors,
    String? readingPace,
    String? purpose,
  }) async {
    final updated = await ref.read(profileRepositoryProvider).saveReadingSurvey(
          favoriteGenres: favoriteGenres,
          favoriteAuthors: favoriteAuthors,
          readingPace: readingPace,
          purpose: purpose,
        );
    state = AsyncData(updated);
    ref.read(authControllerProvider.notifier).setUser(updated);
  }

  /// Poza apare și în header, și în bara de navigare, deci profilul actualizat
  /// se propagă și în authController, ca la orice altă modificare de profil.
  Future<void> uploadPhoto(List<int> bytes, String filename) async {
    final updated = await ref
        .read(profileRepositoryProvider)
        .uploadProfilePhoto(bytes: bytes, filename: filename);
    state = AsyncData(updated);
    ref.read(authControllerProvider.notifier).setUser(updated);
  }

  Future<void> removePhoto() async {
    final updated = await ref.read(profileRepositoryProvider).removeProfilePhoto();
    state = AsyncData(updated);
    ref.read(authControllerProvider.notifier).setUser(updated);
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, AppUser>(
  ProfileController.new,
);
