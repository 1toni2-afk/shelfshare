import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/romanian_cities.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../auth/application/auth_controller.dart';
import '../application/profile_controller.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _sheetOpen = false;

  Future<void> _editProfile(AppUser user) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditProfileSheet(user: user),
    );
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profilul meu')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(profileControllerProvider.notifier).refresh(),
          child: state.when(
            data: (user) => _ProfileContent(
              user: user,
              onEdit: () => _editProfile(user),
            ),
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nu am putut încărca profilul.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(profileControllerProvider.notifier).refresh(),
                    child: const Text('Încearcă din nou'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundImage: user.profileImage != null ? NetworkImage(user.profileImage!) : null,
            child: user.profileImage == null
                ? const Icon(Icons.person, size: 48)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name ?? 'Utilizator',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
          textAlign: TextAlign.center,
        ),
        if (user.city != null) ...[
          const SizedBox(height: 4),
          Text(
            user.city!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatTile(icon: Icons.star, value: user.rating.toStringAsFixed(1), label: 'Rating'),
            _StatTile(value: '${user.booksExchangedCount}', label: 'Cărți schimbate'),
          ],
        ),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Despre mine', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(user.bio!),
        ],
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Schimburile mele'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/exchanges'),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onEdit,
          child: const Text('Editează profilul'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Deconectare'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 4),
            ],
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _bioController = TextEditingController(text: widget.user.bio);
  late String? _city = widget.user.city;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileControllerProvider.notifier).updateProfile(
            name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            city: _city,
            bio: _bioController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nu am putut salva profilul.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Editează profilul', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nume'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'Oraș'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Fără oraș')),
                for (final city in kRomanianCities) DropdownMenuItem(value: city, child: Text(city)),
              ],
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Despre mine'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }
}
