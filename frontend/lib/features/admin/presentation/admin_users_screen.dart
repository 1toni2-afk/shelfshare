import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_controller.dart';
import 'admin_screen.dart';

/// Lista completă de utilizatori, scoasă din dashboard-ul principal de admin
/// (vezi admin_screen.dart) - cu zeci/sute de conturi, umplea pagina și
/// ascundea restul secțiunilor. Aceleași date (adminControllerProvider),
/// doar afișate pe ecran separat.
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.value != null
            ? l10n.adminUsersCount(async.value!.stats.totalUsers)
            : l10n.profileAdminPanel),
      ),
      body: async.when(
        data: (data) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.users.items.length,
          itemBuilder: (context, index) => UserTile(user: data.users.items[index]),
        ),
        loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
        error: (error, _) => CenteredScrollable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.adminLoadError),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(adminControllerProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
