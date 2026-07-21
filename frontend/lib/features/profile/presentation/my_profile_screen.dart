import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/romanian_cities.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/achievements_grid.dart';
import '../../../shared/widgets/trust_score_card.dart';
import '../../../shared/utils/share_link.dart';
import '../../auth/application/auth_controller.dart';
import '../application/profile_controller.dart';
import '../data/feedback_repository.dart';

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
      appBar: AppBar(
        title: const Text('Profilul meu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Copiază linkul',
            onPressed: () {
              final userId = state.value?.id;
              if (userId != null) copyShareLink(context, '/users/$userId');
            },
          ),
        ],
      ),
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
        ProfileHeader(
          profileImage: user.profileImage,
          name: user.name,
          subtitleLines: [user.email, if (user.city != null) user.city!],
          rating: user.rating,
          booksExchangedCount: user.booksExchangedCount,
          bio: user.bio,
          bioTitle: 'Despre mine',
        ),
        if (user.trustScore != null) ...[
          const SizedBox(height: 20),
          TrustScoreCard(trustScore: user.trustScore!),
        ],
        if (user.achievements != null && user.achievements!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Insigne', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AchievementsGrid(achievements: user.achievements!),
        ],
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Schimburile mele'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/exchanges'),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Centru de siguranță'),
          onPressed: () => context.push('/safety-center'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.help_outline),
          label: const Text('Întrebări frecvente'),
          onPressed: () => context.push('/help-center'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.leaderboard_outlined),
          label: const Text('Clasament pe orașe'),
          onPressed: () => context.push('/leaderboard'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.feedback_outlined),
          label: const Text('Trimite feedback'),
          onPressed: () => _showFeedbackDialog(context, ref),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onEdit,
          child: const Text('Editează profilul'),
        ),
        if (user.isAdmin) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Panou de administrare'),
            onPressed: () => context.push('/admin'),
          ),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Deconectare'),
        ),
      ],
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trimite feedback'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Ce ai vrea să ne spui?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anulează')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Trimite'),
          ),
        ],
      ),
    );
    if (message != null && message.trim().length >= 3) {
      try {
        await ref.read(feedbackRepositoryProvider).submit(message.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Mulțumim pentru feedback!')));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Nu am putut trimite feedback-ul')));
        }
      }
    }
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
  late bool _showAcquisitionHistory = widget.user.showAcquisitionHistory;
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
            showAcquisitionHistory: _showAcquisitionHistory,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Arată istoricul de achiziții pe profil'),
              subtitle: const Text('Cărțile pe care le-ai primit prin schimburi sau cumpărături din aplicație'),
              value: _showAcquisitionHistory,
              onChanged: (value) => setState(() => _showAcquisitionHistory = value),
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
