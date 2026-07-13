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

  Future<void> updateProfile({String? name, String? city, String? bio}) async {
    final updated = await ref
        .read(profileRepositoryProvider)
        .updateProfile(name: name, city: city, bio: bio);
    state = AsyncData(updated);
    ref.read(authControllerProvider.notifier).setUser(updated);
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, AppUser>(
  ProfileController.new,
);
