import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/locale/l10n_extensions.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAdminPanel)),
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
                  Text(l10n.adminLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(adminControllerProvider.notifier).refresh(),
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
}

class _AdminContent extends StatelessWidget {
  const _AdminContent({required this.data});
  final AdminData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(l10n.adminChatInboxTitle),
            subtitle: Text(l10n.adminChatInboxDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/chat'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.toggle_on_outlined),
            title: Text(l10n.adminFeatureAccessTitle),
            subtitle: Text(l10n.adminFeatureAccessDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/feature-access'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.trending_up),
            title: const Text('Scor de interes anunț'),
            subtitle: const Text('Popularitate, potențial de schimb, override manual'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/listings/score'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(l10n.adminAdministratorsTitle),
            subtitle: Text(l10n.adminAdministratorsDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/administrators'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.security_outlined),
            title: Text(l10n.adminRolesTitle),
            subtitle: Text(l10n.adminRolesDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/roles'),
          ),
        ),
        const SizedBox(height: 28),
        Text(l10n.adminStatsTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _StatsGrid(stats: data.stats),
        const SizedBox(height: 20),
        _StatsGrowthChart(history: data.statsHistory),
        const SizedBox(height: 28),
        Text(l10n.adminConversionFunnelTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          l10n.adminConversionFunnelDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        _ConversionFunnelChart(funnel: data.conversionFunnel),
        const SizedBox(height: 28),
        Text(l10n.adminMarketplaceStatsTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _MarketplaceStatsGrid(stats: data.marketplaceStats),
        const SizedBox(height: 28),
        Text(l10n.adminActiveZonesTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          l10n.adminActiveZonesDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        _ActiveZonesMap(zones: data.activeZones),
        const SizedBox(height: 28),
        // Utilizatori și anunțuri fără cerere: liste care pot ajunge la sute
        // de rânduri (66 useri + 100 anunțuri inactive într-un caz real) - nu
        // le mai afișăm inline în dashboard, doar un card care deschide un
        // ecran dedicat cu lista completă, ca la Administratori/Roluri mai sus.
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(l10n.adminUsersCount(data.stats.totalUsers)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/users'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l10n.adminInactiveListingsCount(data.inactiveListings.length)),
            subtitle: Text(l10n.adminInactiveListingsDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/listings/inactive'),
          ),
        ),
        const SizedBox(height: 28),
        Text(l10n.adminUserReportsCount(data.userReports.length), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (data.userReports.isEmpty)
          Text(l10n.adminNoReports)
        else
          for (final report in data.userReports) _UserReportTile(report: report),
        const SizedBox(height: 28),
        Text(l10n.adminUpcomingReleasesCount(data.upcomingReleases.length), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          l10n.adminUpcomingReleasesDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        const _AddUpcomingReleaseForm(),
        const SizedBox(height: 12),
        if (data.upcomingReleases.isEmpty)
          Text(l10n.adminNoUpcomingReleases)
        else
          for (final release in data.upcomingReleases) _UpcomingReleaseTile(release: release),
        const SizedBox(height: 28),
        Text(l10n.adminFeedbackCount(data.feedback.length), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (data.feedback.isEmpty)
          Text(l10n.adminNoFeedback)
        else
          for (final item in data.feedback) _FeedbackTile(item: item),
        const SizedBox(height: 28),
        Text(
          l10n.adminSupportRequestsCount(data.supportRequests.length),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (data.supportRequests.isEmpty)
          Text(l10n.adminNoSupportRequests)
        else
          for (final item in data.supportRequests) _SupportRequestTile(item: item),
      ],
    );
  }
}

class _SupportRequestTile extends StatelessWidget {
  const _SupportRequestTile({required this.item});
  final SupportRequestItem item;

  @override
  Widget build(BuildContext context) {
    final contactLine = [item.email, if (item.phone != null && item.phone!.isNotEmpty) item.phone!].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${item.name} — ${item.message}'),
        subtitle: Text(
          '$contactLine · ${item.createdAt.day}.${item.createdAt.month}.${item.createdAt.year}',
        ),
        isThreeLine: item.message.length > 60,
      ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(item.message),
              subtitle: Text(
                '${item.userName ?? item.userEmail} · ${item.createdAt.day}.${item.createdAt.month}.${item.createdAt.year}',
              ),
              isThreeLine: item.message.length > 60,
            ),
            if (item.photoUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.photoUrl!,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserReportTile extends ConsumerWidget {
  const _UserReportTile({required this.report});
  final UserReport report;

  Color _statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.open:
        return AppColors.warning;
      case ReportStatus.inProgress:
        return AppColors.primary;
      case ReportStatus.resolved:
        return AppColors.success;
      case ReportStatus.dismissed:
        return AppColors.mutedForeground;
    }
  }

  String _statusLabel(BuildContext context, ReportStatus status) {
    final l10n = context.l10n;
    switch (status) {
      case ReportStatus.open:
        return l10n.adminReportStatusOpen;
      case ReportStatus.inProgress:
        return l10n.adminReportStatusInProgress;
      case ReportStatus.resolved:
        return l10n.adminReportStatusResolved;
      case ReportStatus.dismissed:
        return l10n.adminReportStatusDismissed;
    }
  }

  Future<void> _applyStatus(BuildContext context, WidgetRef ref, ReportStatus status) async {
    String? note;
    if (status == ReportStatus.resolved || status == ReportStatus.dismissed) {
      final l10n = context.l10n;
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_statusLabel(context, status)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.adminReportResolutionNoteLabel,
              hintText: l10n.adminReportResolutionNoteHint,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonConfirm)),
          ],
        ),
      );
      controller.dispose();
      if (confirmed != true) return;
      note = controller.text.trim();
    }
    if (!context.mounted) return;
    try {
      await ref.read(adminControllerProvider.notifier).updateReportStatus(
            report.id,
            status,
            resolutionNote: note != null && note.isNotEmpty ? note : null,
          );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.adminReportUpdateError)),
        );
      }
    }
  }

  Future<void> _deleteContent(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final isPost = report.groupPostId != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPost ? l10n.adminDeletePostConfirmTitle : l10n.adminDeleteReviewConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonGiveUp)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      if (isPost) {
        await ref.read(adminControllerProvider.notifier).deleteReportedGroupPost(report.groupPostId!);
      } else {
        await ref.read(adminControllerProvider.notifier).deleteReportedReview(report.reviewId!);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminContentDeleted)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminContentDeleteError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assignedName = report.assignedToName ?? report.assignedToEmail;
    final hasContent = report.groupPostId != null || report.reviewId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${report.reportedName ?? report.reportedEmail} - ${report.reason}'),
        subtitle: Text([
          l10n.adminReportedBy(report.reporterName ?? report.reporterEmail),
          assignedName != null ? l10n.adminReportAssignedTo(assignedName) : l10n.adminReportUnassigned,
          if (report.details != null && report.details!.isNotEmpty) report.details!,
          if (report.resolutionNote != null && report.resolutionNote!.isNotEmpty) report.resolutionNote!,
          if (report.groupPostId != null) '${l10n.adminReportedPostLabel}: "${report.groupPostContent}"',
          if (report.reviewId != null)
            '${l10n.adminReportedReviewLabel} (${report.reviewRating}/5)'
                '${report.reviewText != null && report.reviewText!.isNotEmpty ? ": ${report.reviewText}" : ""}',
        ].join('\n')),
        isThreeLine: true,
        leading: Chip(
          label: Text(_statusLabel(context, report.status), style: const TextStyle(fontSize: 11)),
          backgroundColor: _statusColor(report.status).withValues(alpha: 0.15),
          labelStyle: TextStyle(color: _statusColor(report.status)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasContent)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: report.groupPostId != null ? l10n.adminDeletePostAction : l10n.adminDeleteReviewAction,
                onPressed: () => _deleteContent(context, ref),
              ),
            PopupMenuButton<ReportStatus>(
              onSelected: (status) => _applyStatus(context, ref, status),
              itemBuilder: (context) => [
                if (report.status == ReportStatus.open)
                  PopupMenuItem(value: ReportStatus.inProgress, child: Text(l10n.adminReportMarkInProgress)),
                if (report.status != ReportStatus.resolved)
                  PopupMenuItem(value: ReportStatus.resolved, child: Text(l10n.adminReportMarkResolved)),
                if (report.status != ReportStatus.dismissed)
                  PopupMenuItem(value: ReportStatus.dismissed, child: Text(l10n.adminReportMarkDismissed)),
                if (report.status == ReportStatus.resolved || report.status == ReportStatus.dismissed)
                  PopupMenuItem(value: ReportStatus.open, child: Text(l10n.adminReportReopen)),
              ],
            ),
          ],
        ),
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
          '${release.author ?? context.l10n.adminUnknownAuthor} · ${release.releaseDate.day}.${release.releaseDate.month}.${release.releaseDate.year}',
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
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    if (title.isEmpty || _releaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTitleDateRequired)),
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
            .showSnackBar(SnackBar(content: Text(l10n.adminAddBookError)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: _titleController,
              decoration: InputDecoration(hintText: l10n.addBookTitleLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: _authorController,
              decoration: InputDecoration(hintText: l10n.adminAuthorOptional),
            ),
            const SizedBox(height: 12),
            TextField(
              textAlignVertical: TextAlignVertical.center,
              controller: _coverUrlController,
              decoration: InputDecoration(hintText: l10n.adminCoverUrlOptional),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(
                _releaseDate == null
                    ? l10n.adminPickReleaseDate
                    : l10n.adminReleaseDateLabel('${_releaseDate!.day}.${_releaseDate!.month}.${_releaseDate!.year}'),
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
                  : Text(l10n.adminAdd),
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
    final l10n = context.l10n;
    final tiles = [
      (l10n.adminStatsUsersLabel, '${stats.totalUsers}', l10n.adminStatsUsersSubtitle(stats.verifiedUsers)),
      (l10n.adminStatsBooksLabel, '${stats.totalBooks}', l10n.adminStatsBooksSubtitle(stats.totalListings)),
      (
        l10n.adminStatsExchangesLabel,
        '${stats.totalExchanges}',
        l10n.adminStatsExchangesSubtitle(stats.completedExchanges, stats.pendingExchanges),
      ),
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

/// "Growth over time" (feature backlog #10) - un rând pe zi din
/// StatsSnapshot (vezi AdminService#snapshotDailyStats), ca panoul să arate
/// tendința, nu doar instantaneul curent din _StatsGrid de mai sus.
class _StatsGrowthChart extends StatelessWidget {
  const _StatsGrowthChart({required this.history});
  final List<StatsSnapshotPoint> history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminStatsGrowthTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.adminStatsGrowthDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            // Sub 2 puncte nu există o linie de trasat.
            if (history.length < 2)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    l10n.adminStatsGrowthEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            else
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        spots: [
                          for (var i = 0; i < history.length; i++)
                            FlSpot(i.toDouble(), history[i].totalUsers.toDouble()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.adminStatsGrowthRange(history.first.totalUsers, history.last.totalUsers),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Feature backlog #19: pre-înscriere -> onboarding -> primul anunț -> primul
/// schimb finalizat. Bare proporționale simple, fără fl_chart - fiecare
/// treaptă e independentă, nu neapărat un subset strict al celei de dinainte.
class _ConversionFunnelChart extends StatelessWidget {
  const _ConversionFunnelChart({required this.funnel});
  final ConversionFunnel funnel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stages = [
      (l10n.adminFunnelPreRegistrations, funnel.preRegistrations),
      (l10n.adminFunnelRegistered, funnel.registeredUsers),
      (l10n.adminFunnelOnboarded, funnel.onboardedUsers),
      (l10n.adminFunnelListedBook, funnel.listedUsers),
      (l10n.adminFunnelExchanged, funnel.exchangedUsers),
    ];
    final maxValue = stages.map((s) => s.$2).fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final stage in stages) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(stage.$1, style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Text('${stage.$2}', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxValue == 0 ? 0 : stage.$2 / maxValue,
                  minHeight: 10,
                  backgroundColor: AppColors.muted,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketplaceStatsGrid extends StatelessWidget {
  const _MarketplaceStatsGrid({required this.stats});
  final MarketplaceStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tiles = [
      (l10n.adminMarketplaceGmv, l10n.priceLei(stats.gmv.toStringAsFixed(0)), ''),
      (l10n.adminMarketplaceCompletedSales, '${stats.completedSalesCount}', ''),
      (l10n.adminMarketplaceCompletedAuctions, '${stats.completedAuctionsCount}', ''),
      (l10n.adminMarketplaceAvgPrice, l10n.priceLei(stats.averageSalePrice.toStringAsFixed(0)), ''),
    ];
    return Column(
      children: [
        for (final t in tiles)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.$1, style: Theme.of(context).textTheme.bodyMedium),
                  Text(t.$2, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ),
        if (stats.topGenresByListings.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.adminMarketplaceTopGenres, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: stats.topGenresByListings.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final g = stats.topGenresByListings[index];
                        return Chip(label: Text('${g.genre} (${g.count})'));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const _romaniaCenterAdmin = LatLng(45.9432, 24.9668);

/// "Heatmap" simplificat - cercuri semi-transparente pe hartă, raza/opacitatea
/// scalate relativ la cel mai activ oraș, fără o dependință nouă de heatmap
/// (flutter_map_heatmap etc.) - suficient ca semnal vizual la scara aplicației.
class _ActiveZonesMap extends StatelessWidget {
  const _ActiveZonesMap({required this.zones});
  final List<ActiveZone> zones;

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty) {
      return Text(context.l10n.adminActiveZonesEmpty);
    }
    final maxCount = zones.map((z) => z.count).reduce((a, b) => a > b ? a : b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 320,
        child: FlutterMap(
          options: const MapOptions(initialCenter: _romaniaCenterAdmin, initialZoom: 6.0),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.shelfshare.app',
              maxZoom: 20,
            ),
            CircleLayer(
              circles: [
                for (final zone in zones)
                  CircleMarker(
                    point: LatLng(zone.lat, zone.lng),
                    radius: 10 + (zone.count / maxCount) * 40,
                    color: AppColors.accent.withValues(alpha: 0.35),
                    borderColor: AppColors.accent,
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserTile extends ConsumerWidget {
  const UserTile({super.key, required this.user});
  final AdminUser user;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminDeleteUserTitle),
        content: Text(
          l10n.adminDeleteUserBody(user.name ?? user.email),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete, style: const TextStyle(color: AppColors.destructive)),
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
    final l10n = context.l10n;
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
            if (user.isPremium)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.workspace_premium, size: 16, color: AppColors.warning),
              ),
          ],
        ),
        subtitle: Text(
          '${user.email}${user.city != null ? " · ${user.city}" : ""} · ${user.rating.toStringAsFixed(1)}★ · ${l10n.leaderboardExchangesCount(user.booksExchangedCount)}',
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
              case 'toggle-premium':
                notifier.togglePremium(user.id, currentValue: user.isPremium);
              case 'delete':
                _confirmAndDelete(context, ref);
            }
          },
          itemBuilder: (context) => [
            if (user.isBanned)
              PopupMenuItem(value: 'unban', child: Text(l10n.chatUnblock))
            else
              PopupMenuItem(value: 'ban', child: Text(l10n.chatBlock)),
            PopupMenuItem(
              value: 'toggle-premium',
              child: Text(user.isPremium ? l10n.adminRemovePremium : l10n.adminGrantPremium),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(l10n.commonDelete, style: const TextStyle(color: AppColors.destructive)),
            ),
          ],
        ),
      ),
    );
  }
}

class InactiveListingTile extends ConsumerWidget {
  const InactiveListingTile({super.key, required this.listing});
  final InactiveListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(listing.bookTitle, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${listing.bookAuthor ?? context.l10n.adminUnknownAuthor} · ${listing.ownerName ?? listing.ownerEmail}',
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
