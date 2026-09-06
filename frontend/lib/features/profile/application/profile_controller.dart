import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/profile_repository.dart';

class ProfileController extends AsyncNotifier<AppUser> {
  @override
  Future<AppUser> build() {
    return ref.read(profileRepositoryProvider).getMyProfile();
  }

  /// Reîncarcă profilul de pe server. Rezultatul se propagă și în
  /// `authController`: routerul decide pe copia DE ACOLO dacă mai ține userul
  /// în onboarding sau pe ecranul de verificare a emailului, deci un refresh
  /// care actualiza doar starea asta lăsa routerul cu date vechi.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).getMyProfile());
    final user = state.value;
    if (user != null) ref.read(authControllerProvider.notifier).setUser(user);
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
    bool? hideSwapListingsPublic,
    bool? hideSaleListingsPublic,
    bool? hideDonationListingsPublic,
    bool? hideAuctionListingsPublic,
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
          hideSwapListingsPublic: hideSwapListingsPublic,
          hideSaleListingsPublic: hideSaleListingsPublic,
          hideDonationListingsPublic: hideDonationListingsPublic,
          hideAuctionListingsPublic: hideAuctionListingsPublic,
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

/// Userul autentificat ACUM, cu datele complete de profil când sunt ale lui.
///
/// De ce nu se citește direct `profileControllerProvider.value`: providerul
/// acela nu se resetează la logout, iar cât timp reîncarcă, `AsyncValue`
/// păstrează valoarea PRECEDENTĂ (`copyWithPrevious`). Imediat după un login
/// pe alt cont, acea valoare e profilul contului DINAINTE - footer-ul din
/// sidebar arăta userul anterior până la prima reconstruire, iar `isAdmin`
/// citit așa putea trimite un user obișnuit pe ruta de admin.
///
/// Starea de auth, în schimb, se schimbă atomic la login, cu userul din
/// răspunsul serverului. Preferăm profilul (are poza și câmpurile actualizate
/// după o editare) DOAR când e chiar al lui; altfel cădem pe userul din auth,
/// care e mereu corect ca identitate.
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final authUser = authState is AuthAuthenticated ? authState.user : null;
  if (authUser == null) return null;

  final profile = ref.watch(profileControllerProvider).value;
  return profile != null && profile.id == authUser.id ? profile : authUser;
});
