import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../application/admin_controller.dart';
import '../data/admin_repository.dart';

String reportStatusLabel(BuildContext context, ReportStatus status) {
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

/// Un raport din coada de moderare, cu acțiunile rapide pe el.
///
/// Trăia inline în `admin_screen.dart`; a ieșit de acolo când coada a primit
/// panoul ei filtrabil - același rând trebuie să arate și să se comporte la
/// fel în ambele locuri. [onChanged] anunță ecranul care ține lista să se
/// reîmprospăteze după o acțiune.
class UserReportTile extends ConsumerWidget {
  const UserReportTile({super.key, required this.report, this.onChanged});

  final UserReport report;
  final VoidCallback? onChanged;

  Future<void> _applyStatus(
    BuildContext context,
    WidgetRef ref,
    ReportStatus status,
  ) async {
    String? note;
    if (status == ReportStatus.resolved || status == ReportStatus.dismissed) {
      final l10n = context.l10n;
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(reportStatusLabel(context, status)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.adminReportResolutionNoteLabel,
              hintText: l10n.adminReportResolutionNoteHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonConfirm),
            ),
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
      onChanged?.call();
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
        title: Text(isPost
            ? l10n.adminDeletePostConfirmTitle
            : l10n.adminDeleteReviewConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonGiveUp),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      if (isPost) {
        await ref
            .read(adminControllerProvider.notifier)
            .deleteReportedGroupPost(report.groupPostId!);
      } else {
        await ref
            .read(adminControllerProvider.notifier)
            .deleteReportedReview(report.reviewId!);
      }
      onChanged?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminContentDeleted)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminContentDeleteError)),
        );
      }
    }
  }

  /// Repune conținutul ascuns automat de praguri. Ascunderea automată e o
  /// măsură provizorie luată fără om în buclă, deci drumul înapoi trebuie să
  /// fie la fel de la îndemână ca ștergerea.
  Future<void> _unhide(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref.read(adminRepositoryProvider).unhideReportTarget(report.id);
      onChanged?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminContentRestored)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminReportUpdateError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assignedName = report.assignedToName ?? report.assignedToEmail;
    final hasDeletableContent =
        report.groupPostId != null || report.reviewId != null;
    final isHidden = report.contentHiddenAt != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${report.reportedName ?? report.reportedEmail} - ${report.reason}',
              ),
            ),
            if (isHidden)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text(
                    l10n.adminReportAutoHidden,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: AppColors.warning),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text([
          l10n.adminReportedBy(report.reporterName ?? report.reporterEmail),
          assignedName != null
              ? l10n.adminReportAssignedTo(assignedName)
              : l10n.adminReportUnassigned,
          if (report.details != null && report.details!.isNotEmpty)
            report.details!,
          if (report.resolutionNote != null &&
              report.resolutionNote!.isNotEmpty)
            report.resolutionNote!,
          if (report.userBookTitle != null)
            '${l10n.adminReportTargetListing}: "${report.userBookTitle}"',
          if (report.groupPostId != null)
            '${l10n.adminReportedPostLabel}: "${report.groupPostContent}"',
          if (report.reviewId != null)
            '${l10n.adminReportedReviewLabel} (${report.reviewRating}/5)'
                '${report.reviewText != null && report.reviewText!.isNotEmpty ? ": ${report.reviewText}" : ""}',
        ].join('\n')),
        isThreeLine: true,
        leading: Chip(
          label: Text(
            reportStatusLabel(context, report.status),
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: _statusColor(report.status).withValues(alpha: 0.15),
          labelStyle: TextStyle(color: _statusColor(report.status)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHidden && report.targetType.isHideable)
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: l10n.adminReportUnhideAction,
                onPressed: () => _unhide(context, ref),
              ),
            if (hasDeletableContent)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: report.groupPostId != null
                    ? l10n.adminDeletePostAction
                    : l10n.adminDeleteReviewAction,
                onPressed: () => _deleteContent(context, ref),
              ),
            PopupMenuButton<ReportStatus>(
              onSelected: (status) => _applyStatus(context, ref, status),
              itemBuilder: (context) => [
                if (report.status == ReportStatus.open)
                  PopupMenuItem(
                    value: ReportStatus.inProgress,
                    child: Text(l10n.adminReportMarkInProgress),
                  ),
                if (report.status != ReportStatus.resolved)
                  PopupMenuItem(
                    value: ReportStatus.resolved,
                    child: Text(l10n.adminReportMarkResolved),
                  ),
                if (report.status != ReportStatus.dismissed)
                  PopupMenuItem(
                    value: ReportStatus.dismissed,
                    child: Text(l10n.adminReportMarkDismissed),
                  ),
                if (report.status == ReportStatus.resolved ||
                    report.status == ReportStatus.dismissed)
                  PopupMenuItem(
                    value: ReportStatus.open,
                    child: Text(l10n.adminReportReopen),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
