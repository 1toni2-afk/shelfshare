import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_controller.dart';
import 'admin_screen.dart';

/// Anunțurile fără nicio cerere de schimb, scoase din dashboard-ul principal
/// (vezi admin_screen.dart) - puteau ajunge la ~100 rânduri, ocupând pagina
/// degeaba. Aceleași date (adminControllerProvider), doar afișate separat.
class AdminInactiveListingsScreen extends ConsumerWidget {
  const AdminInactiveListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.value != null
            ? l10n.adminInactiveListingsCount(async.value!.inactiveListings.length)
            : l10n.profileAdminPanel),
      ),
      body: async.when(
        data: (data) => data.inactiveListings.isEmpty
            ? CenteredScrollable(child: Text(l10n.adminNoInactiveListings))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: data.inactiveListings.length,
                itemBuilder: (context, index) =>
                    InactiveListingTile(listing: data.inactiveListings[index]),
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
