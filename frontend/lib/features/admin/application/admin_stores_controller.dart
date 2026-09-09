import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/store.dart';
import '../data/admin_repository.dart';

/// Conturile de anticariat/librărie, pentru panoul de super-admin.
///
/// Fiecare scriere reîncarcă lista: sunt câteva zeci de rânduri și o singură
/// cerere, iar starea „activ / suspendat" și numărul de anunțuri sunt calculate
/// pe backend - o actualizare optimistă locală ar fi trebuit să le ghicească.
class AdminStoresController extends AsyncNotifier<List<StoreAccount>> {
  @override
  Future<List<StoreAccount>> build() => _load();

  Future<List<StoreAccount>> _load() =>
      ref.read(adminRepositoryProvider).listStores();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> create({required String userId, required StoreProfile profile}) async {
    await ref.read(adminRepositoryProvider).createStore(userId: userId, profile: profile);
    await refresh();
  }

  /// Numele nu e `update`: AsyncNotifier are deja un membru cu numele ăsta.
  Future<void> save({
    required String userId,
    required StoreProfile profile,
    required bool isActive,
  }) async {
    await ref
        .read(adminRepositoryProvider)
        .updateStore(userId: userId, profile: profile, isActive: isActive);
    await refresh();
  }

  Future<void> remove(String userId) async {
    await ref.read(adminRepositoryProvider).deleteStore(userId);
    await refresh();
  }
}

final adminStoresControllerProvider =
    AsyncNotifierProvider<AdminStoresController, List<StoreAccount>>(
  AdminStoresController.new,
);
