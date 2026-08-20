import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/admin_models.dart';
import '../data/admin_repository.dart';

class AdminRolesData {
  const AdminRolesData({required this.administrators, required this.roles});

  final List<Administrator> administrators;
  final AdminRolesPage roles;

  AdminRolesData copyWith({List<Administrator>? administrators, AdminRolesPage? roles}) {
    return AdminRolesData(
      administrators: administrators ?? this.administrators,
      roles: roles ?? this.roles,
    );
  }
}

class AdminRolesController extends AsyncNotifier<AdminRolesData> {
  @override
  Future<AdminRolesData> build() => _load();

  Future<AdminRolesData> _load() async {
    final repository = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repository.getAdministrators(),
      repository.getRoles(),
    ]);
    return AdminRolesData(
      administrators: results[0] as List<Administrator>,
      roles: results[1] as AdminRolesPage,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> grantAdminRole(String userId, String roleId) async {
    await ref.read(adminRepositoryProvider).grantAdminRole(userId, roleId);
    await refresh();
  }

  Future<void> updateAdminRole(String userId, String roleId) async {
    await ref.read(adminRepositoryProvider).updateAdminRole(userId, roleId);
    await refresh();
  }

  Future<void> revokeAdmin(String userId) async {
    await ref.read(adminRepositoryProvider).revokeAdmin(userId);
    await refresh();
  }

  Future<void> createCustomRole(String label, List<String> permissions) async {
    await ref.read(adminRepositoryProvider).createCustomRole(label, permissions);
    await refresh();
  }

  Future<void> updateCustomRole(String roleId, String label, List<String> permissions) async {
    await ref.read(adminRepositoryProvider).updateCustomRole(roleId, label, permissions);
    await refresh();
  }
}

final adminRolesControllerProvider =
    AsyncNotifierProvider<AdminRolesController, AdminRolesData>(AdminRolesController.new);
