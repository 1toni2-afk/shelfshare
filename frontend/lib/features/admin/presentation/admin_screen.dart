import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/upcoming_release.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_controller.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Panou de administrare')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(adminControllerProvider.notifier).refresh(),
          child: async.when(
            data: (data) => _AdminContent(data: data),
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nu am putut încărca datele de admin.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(adminControllerProvider.notifier).refresh(),
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

class _AdminContent extends StatelessWidget {
  const _AdminContent({required this.data});
  final AdminData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Statistici', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _StatsGrid(stats: data.stats),
        const SizedBox(height: 28),
        Text('Utilizatori (${data.stats.totalUsers})', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final user in data.users.items) _UserTile(user: user),
        const SizedBox(height: 28),
        Text(
          'Anunțuri fără nicio cerere (${data.inactiveListings.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Cărți puse la schimb pentru care nimeni nu a trimis nicio cerere.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        if (data.inactiveListings.isEmpty)
          const Text('Niciun anunț inactiv.')
        else
          for (final listing in data.inactiveListings) _InactiveListingTile(listing: listing),
        const SizedBox(height: 28),
        Text('Rapoarte utilizatori (${data.userReports.length})', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (data.userReports.isEmpty)
          const Text('Niciun raport.')
        else
          for (final report in data.userReports) _UserReportTile(report: report),
        const SizedBox(height: 28),
        Text('Cărți viitoare (${data.upcomingReleases.length})', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Afișate pe ecranul principal, în secțiunea "Cărți viitoare".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        const _AddUpcomingReleaseForm(),
        const SizedBox(height: 12),
        if (data.upcomingReleases.isEmpty)
          const Text('Nicio carte viitoare adăugată.')
        else
          for (final release in data.upcomingReleases) _UpcomingReleaseTile(release: release),
        const SizedBox(height: 28),
        Text('Feedback primit (${data.feedback.length})', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (data.feedback.isEmpty)
          const Text('Niciun feedback trimis încă.')
        else
          for (final item in data.feedback) _FeedbackTile(item: item),
      ],
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});
  final FeedbackItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.message),
        subtitle: Text(
          '${item.userName ?? item.userEmail} · ${item.createdAt.day}.${item.createdAt.month}.${item.createdAt.year}',
        ),
        isThreeLine: item.message.length > 60,
      ),
    );
  }
}

class _UserReportTile extends StatelessWidget {
  const _UserReportTile({required this.report});
  final UserReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${report.reportedName ?? report.reportedEmail} - ${report.reason}'),
        subtitle: Text(
          'Raportat de ${report.reporterName ?? report.reporterEmail}'
          '${report.details != null && report.details!.isNotEmpty ? '\n${report.details}' : ''}',
        ),
        isThreeLine: report.details != null && report.details!.isNotEmpty,
      ),
    );
  }
}

class _UpcomingReleaseTile extends ConsumerWidget {
  const _UpcomingReleaseTile({required this.release});
  final UpcomingRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: BookCover(url: release.coverUrl, width: 40, height: 56),
        title: Text(release.title, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${release.author ?? "Autor necunoscut"} · ${release.releaseDate.day}.${release.releaseDate.month}.${release.releaseDate.year}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
          onPressed: () => ref.read(adminControllerProvider.notifier).deleteUpcomingRelease(release.id),
        ),
      ),
    );
  }
}

class _AddUpcomingReleaseForm extends ConsumerStatefulWidget {
  const _AddUpcomingReleaseForm();

  @override
  ConsumerState<_AddUpcomingReleaseForm> createState() => _AddUpcomingReleaseFormState();
}

class _AddUpcomingReleaseFormState extends ConsumerState<_AddUpcomingReleaseForm> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _coverUrlController = TextEditingController();
  DateTime? _releaseDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _releaseDate = picked);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _releaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titlul și data lansării sunt obligatorii')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminControllerProvider.notifier).createUpcomingRelease(
            title: title,
            author: _authorController.text.trim().isEmpty ? null : _authorController.text.trim(),
            coverUrl: _coverUrlController.text.trim().isEmpty ? null : _coverUrlController.text.trim(),
            releaseDate: _releaseDate!,
          );
      _titleController.clear();
      _authorController.clear();
      _coverUrlController.clear();
      if (mounted) setState(() => _releaseDate = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nu am putut adăuga cartea')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titlu'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Autor (opțional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coverUrlController,
              decoration: const InputDecoration(labelText: 'URL copertă (opțional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(
                _releaseDate == null
                    ? 'Alege data lansării'
                    : 'Lansare: ${_releaseDate!.day}.${_releaseDate!.month}.${_releaseDate!.year}',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Utilizatori', '${stats.totalUsers}', 'din care ${stats.verifiedUsers} verificați'),
      ('Cărți în catalog', '${stats.totalBooks}', '${stats.totalListings} exemplare listate'),
      ('Schimburi', '${stats.totalExchanges}', '${stats.completedExchanges} finalizate · ${stats.pendingExchanges} în așteptare'),
    ];
    return Column(
      children: [
        for (final t in tiles)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$1, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(t.$3, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  Text(t.$2, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});
  final AdminUser user;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge utilizatorul?'),
        content: Text(
          'Se șterg definitiv contul lui ${user.name ?? user.email} și toate datele asociate (cărți, schimburi, mesaje). Nu se poate anula.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anulează')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(adminControllerProvider.notifier).deleteUser(user.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name ?? user.email,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isAdmin)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.shield, size: 16, color: AppColors.accent),
              ),
            if (user.isBanned)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.block, size: 16, color: AppColors.destructive),
              ),
          ],
        ),
        subtitle: Text(
          '${user.email}${user.city != null ? " · ${user.city}" : ""} · ${user.rating.toStringAsFixed(1)}★ · ${user.booksExchangedCount} schimburi',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            final notifier = ref.read(adminControllerProvider.notifier);
            switch (value) {
              case 'ban':
                notifier.banUser(user.id);
              case 'unban':
                notifier.unbanUser(user.id);
              case 'delete':
                _confirmAndDelete(context, ref);
            }
          },
          itemBuilder: (context) => [
            if (user.isBanned)
              const PopupMenuItem(value: 'unban', child: Text('Deblochează'))
            else
              const PopupMenuItem(value: 'ban', child: Text('Blochează')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Șterge', style: TextStyle(color: AppColors.destructive)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveListingTile extends ConsumerWidget {
  const _InactiveListingTile({required this.listing});
  final InactiveListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(listing.bookTitle, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${listing.bookAuthor ?? "Autor necunoscut"} · ${listing.ownerName ?? listing.ownerEmail}',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
          onPressed: () => ref.read(adminControllerProvider.notifier).deleteUserBook(listing.id),
        ),
      ),
    );
  }
}
