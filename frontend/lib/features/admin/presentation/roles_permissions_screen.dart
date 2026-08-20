import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_roles_controller.dart';

/// Ecran de admin pentru rolurile predefinite + CUSTOM (Admin Control Panel,
/// Milestone 19). Rolurile predefinite (SUPER_ADMIN/MODERATOR/
/// CONTENT_MODERATOR/USER_SUPPORT) au permisiunile fixate în backend, ca
/// sensul lor să rămână stabil - doar rolurile CUSTOM se pot crea/edita aici.
class RolesPermissionsScreen extends ConsumerWidget {
  const RolesPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRolesControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminRolesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.adminRolesCreateCustom),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(adminRolesControllerProvider.notifier).refresh(),
          child: async.when(
            data: (data) => _RolesList(roles: data.roles),
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

  Future<void> _showRoleDialog(BuildContext context, [AdminRole? role]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _RoleEditorDialog(role: role),
    );
  }
}

class _RolesList extends StatelessWidget {
  const _RolesList({required this.roles});
  final AdminRolesPage roles;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (final role in roles.roles)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(role.label, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (role.isCustom)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => _RoleEditorDialog(role: role),
                          ),
                        ),
                    ],
                  ),
                  if (!role.isCustom)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.adminRolesBuiltIn,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final permission in role.permissions) Chip(label: Text(permission)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RoleEditorDialog extends ConsumerStatefulWidget {
  const _RoleEditorDialog({this.role});
  final AdminRole? role;

  @override
  ConsumerState<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends ConsumerState<_RoleEditorDialog> {
  late final _labelController = TextEditingController(text: widget.role?.label ?? '');
  late Map<String, bool> _selected = {
    for (final key in kAdminPermissionKeys) key: widget.role?.permissions.contains(key) ?? false,
  };
  bool _saving = false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    final permissions = [for (final entry in _selected.entries) if (entry.value) entry.key];

    setState(() => _saving = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final notifier = ref.read(adminRolesControllerProvider.notifier);
      if (widget.role != null) {
        await notifier.updateCustomRole(widget.role!.id, label, permissions);
      } else {
        await notifier.createCustomRole(label, permissions);
      }
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminRolesSaveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(widget.role != null ? widget.role!.label : l10n.adminRolesCreateCustom),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelController,
                decoration: InputDecoration(hintText: l10n.adminRolesLabelHint),
              ),
              const SizedBox(height: 8),
              for (final key in kAdminPermissionKeys)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _selected[key] ?? false,
                  title: Text(key),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selected = {..._selected, key: value ?? false}),
                ),
            ],
          ),
        ),
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
              : Text(l10n.adminRolesSave),
        ),
      ],
    );
  }
}
