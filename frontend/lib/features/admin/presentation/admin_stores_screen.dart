import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/store.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_stores_controller.dart';
import 'admin_user_picker.dart';

/// Conturile de anticariat/librărie - doar pentru super-admini.
///
/// Un magazin e un cont obișnuit marcat ca atare: aici i se dau datele
/// comerciale (nume, program, livrare) și de aici i se retrag. Ce câștigă un
/// astfel de cont e dreptul de a-și importa stocul cu preț - inclusiv de a
/// lista la vânzare fără pozele cerute tuturor - deci aprobarea e manuală.
class AdminStoresScreen extends ConsumerWidget {
  const AdminStoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(adminStoresControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminStoresTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, store: null),
        icon: const Icon(Icons.storefront_outlined),
        label: Text(l10n.adminStoresAdd),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(adminStoresControllerProvider.notifier).refresh(),
          child: async.when(
            data: (stores) => _StoresList(
              stores: stores,
              onEdit: (store) => _openEditor(context, ref, store: store),
              onRemove: (store) => _confirmRemove(context, ref, store),
            ),
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.commonGenericError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(adminStoresControllerProvider.notifier).refresh(),
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

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    required StoreAccount? store,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StoreEditorDialog(store: store),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    StoreAccount store,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.adminStoreRemove),
        content: Text(l10n.adminStoreRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(adminStoresControllerProvider.notifier).remove(store.userId);
  }
}

class _StoresList extends StatelessWidget {
  const _StoresList({
    required this.stores,
    required this.onEdit,
    required this.onRemove,
  });

  final List<StoreAccount> stores;
  final ValueChanged<StoreAccount> onEdit;
  final ValueChanged<StoreAccount> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (stores.isEmpty) {
      return CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminStoresEmpty, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              l10n.adminStoresSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: stores.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final store = stores[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => onEdit(store),
            leading: Icon(
              Icons.storefront_outlined,
              color: store.isActive ? AppColors.accent : AppColors.mutedForeground,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(store.profile.displayName, overflow: TextOverflow.ellipsis),
                ),
                if (!store.isActive)
                  Text(
                    l10n.adminStoreSuspended,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.destructive),
                  ),
              ],
            ),
            subtitle: Text(
              '${store.email} · ${l10n.adminStoreListings(store.listingsCount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.adminStoreRemove,
              onPressed: () => onRemove(store),
            ),
          ),
        );
      },
    );
  }
}

/// Formularul de creare/editare. La creare cere întâi contul (căutare după
/// nume/@username/email, ca peste tot în panou - `id` e un UUID pe care nimeni
/// nu-l are la îndemână); la editare contul e deja fixat.
class _StoreEditorDialog extends ConsumerStatefulWidget {
  const _StoreEditorDialog({required this.store});
  final StoreAccount? store;

  @override
  ConsumerState<_StoreEditorDialog> createState() => _StoreEditorDialogState();
}

class _StoreEditorDialogState extends ConsumerState<_StoreEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _website;
  late final TextEditingController _phone;
  late final TextEditingController _hours;
  late final TextEditingController _delivery;

  AdminUser? _selectedUser;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.store?.profile;
    _name = TextEditingController(text: profile?.displayName ?? '');
    _description = TextEditingController(text: profile?.description ?? '');
    _address = TextEditingController(text: profile?.address ?? '');
    _city = TextEditingController(text: profile?.city ?? '');
    _website = TextEditingController(text: profile?.website ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
    _hours = TextEditingController(text: profile?.openingHours ?? '');
    _delivery = TextEditingController(text: profile?.deliveryPolicy ?? '');
    _isActive = widget.store?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _address,
      _city,
      _website,
      _phone,
      _hours,
      _delivery,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  StoreProfile _profile(String userId) => StoreProfile(
        userId: userId,
        displayName: _name.text.trim(),
        description: _description.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        website: _website.text.trim(),
        phone: _phone.text.trim(),
        openingHours: _hours.text.trim(),
        deliveryPolicy: _delivery.text.trim(),
      );

  Future<void> _save() async {
    final l10n = context.l10n;
    final store = widget.store;
    final userId = store?.userId ?? _selectedUser?.id;
    if (userId == null) {
      setState(() => _error = l10n.adminStoreUserRequired);
      return;
    }
    if (_name.text.trim().length < 2) {
      setState(() => _error = l10n.adminStoreNameRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(adminStoresControllerProvider.notifier);
      if (store == null) {
        await controller.create(userId: userId, profile: _profile(userId));
      } else {
        await controller.save(
          userId: userId,
          profile: _profile(userId),
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      // Mesajul serverului e mai util decât unul generic: „contul e deja
      // magazin", „utilizator negăsit" etc.
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List
              ? (data['message'] as List).join(', ')
              : data['message'].toString())
          : l10n.commonGenericError;
      if (mounted) {
        setState(() {
          _error = message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = l10n.commonGenericError;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNew = widget.store == null;

    return AlertDialog(
      title: Text(isNew ? l10n.adminStoresAdd : l10n.adminStoresEdit),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNew) ...[
                Text(l10n.adminStoresPickUser, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                AdminUserPicker(
                  selected: _selectedUser,
                  onSelected: (user) => setState(() => _selectedUser = user),
                ),
                const SizedBox(height: 16),
              ],
              _field(_name, l10n.adminStoreName),
              _field(_description, l10n.adminStoreDescription, maxLines: 3),
              _field(_hours, l10n.adminStoreHours),
              _field(_delivery, l10n.adminStoreDelivery, maxLines: 2),
              _field(_address, l10n.adminStoreAddress),
              _field(_city, l10n.adminStoreCity),
              _field(_website, l10n.adminStoreWebsite),
              _field(_phone, l10n.adminStorePhone),
              if (!isNew)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: Text(l10n.adminStoreActive),
                  subtitle: Text(
                    l10n.adminStoreActiveHint,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.destructive),
                ),
              ],
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
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.commonSave),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        // Alinierea pe verticală se pune per câmp: `isDense` din temă nu e
        // suficientă pentru câmpurile cu mai multe rânduri.
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
