import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_roles_controller.dart';

/// Ecran de admin pentru gestionarea administratorilor (Admin Control Panel,
/// Milestone 19) - acordă/schimbă/elimină rolul unui utilizator. Regulile de
/// securitate (nu-ți poți modifica propriul rol, nu poți acorda o permisiune
/// pe care nu o deții, ultimul Super Admin nu poate fi eliminat) sunt
/// aplicate în backend (AdminManagementService) - aici doar afișăm eroarea.
class AdministratorsScreen extends ConsumerWidget {
  const AdministratorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRolesControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminAdministratorsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(l10n.adminAdministratorsAddButton),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(adminRolesControllerProvider.notifier).refresh(),
          child: async.when(
            data: (data) => _AdministratorsList(data: data),
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.adminAdministratorsLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(adminRolesControllerProvider.notifier).refresh(),
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final data = ref.read(adminRolesControllerProvider).value;
    if (data == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _GrantRoleDialog(roles: data.roles.roles),
    );
  }
}

class _AdministratorsList extends ConsumerWidget {
  const _AdministratorsList({required this.data});
  final AdminRolesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    if (data.administrators.isEmpty) {
      return CenteredScrollable(
        child: Text(
          l10n.adminAdministratorsNoRole,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (final admin in data.administrators)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(admin.name ?? admin.email, overflow: TextOverflow.ellipsis),
              subtitle: Text(admin.adminRole?.label ?? l10n.adminAdministratorsNoRole),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'revoke') {
                    await _revoke(context, ref, admin);
                  } else {
                    await _showChangeRoleDialog(context, ref, admin, data.roles.roles);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'change',
                    child: Text(l10n.adminAdministratorsChangeRole),
                  ),
                  PopupMenuItem(
                    value: 'revoke',
                    child: Text(l10n.adminAdministratorsRevoke),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, Administrator admin) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRolesControllerProvider.notifier).revokeAdmin(admin.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminAdministratorsRevokeError)));
    }
  }

  Future<void> _showChangeRoleDialog(
    BuildContext context,
    WidgetRef ref,
    Administrator admin,
    List<AdminRole> roles,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _GrantRoleDialog(roles: roles, existingUserId: admin.id),
    );
  }
}

class _GrantRoleDialog extends ConsumerStatefulWidget {
  const _GrantRoleDialog({required this.roles, this.existingUserId});

  final List<AdminRole> roles;
  final String? existingUserId;

  @override
  ConsumerState<_GrantRoleDialog> createState() => _GrantRoleDialogState();
}

class _GrantRoleDialogState extends ConsumerState<_GrantRoleDialog> {
  final _userIdController = TextEditingController();
  String? _selectedRoleId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingUserId != null) {
      _userIdController.text = widget.existingUserId!;
    }
    if (widget.roles.isNotEmpty) {
      _selectedRoleId = widget.roles.first.id;
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final roleId = _selectedRoleId;
    final userId = _userIdController.text.trim();
    if (roleId == null || userId.isEmpty) return;

    setState(() => _saving = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final notifier = ref.read(adminRolesControllerProvider.notifier);
      if (widget.existingUserId != null) {
        await notifier.updateAdminRole(userId, roleId);
      } else {
        await notifier.grantAdminRole(userId, roleId);
      }
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminAdministratorsGrantError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEdit = widget.existingUserId != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.adminAdministratorsChangeRole : l10n.adminAdministratorsAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isEdit)
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: _userIdController,
              decoration: InputDecoration(hintText: l10n.adminAdministratorsUserIdHint),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedRoleId,
            decoration: InputDecoration(labelText: l10n.adminAdministratorsRoleHint),
            items: [
              for (final role in widget.roles)
                DropdownMenuItem(value: role.id, child: Text(role.label)),
            ],
            onChanged: (value) => setState(() => _selectedRoleId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.adminAdministratorsAddButton),
        ),
      ],
    );
  }
}
