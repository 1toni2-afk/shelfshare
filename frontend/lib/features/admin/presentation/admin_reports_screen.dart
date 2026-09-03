import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/page_container.dart';
import '../data/admin_repository.dart';
import 'report_tile.dart';

/// Filtrele active ale cozii de moderare. `null` pe oricare înseamnă „toate".
class ReportFilters {
  const ReportFilters({this.targetType, this.status});

  final ReportTargetType? targetType;
  final ReportStatus? status;

  ReportFilters withTargetType(ReportTargetType? value) =>
      ReportFilters(targetType: value, status: status);

  ReportFilters withStatus(ReportStatus? value) =>
      ReportFilters(targetType: targetType, status: value);

  @override
  bool operator ==(Object other) =>
      other is ReportFilters &&
      other.targetType == targetType &&
      other.status == status;

  @override
  int get hashCode => Object.hash(targetType, status);
}

final _reportsProvider =
    FutureProvider.autoDispose.family<List<UserReport>, ReportFilters>(
  (ref, filters) => ref.watch(adminRepositoryProvider).getUserReports(
        targetType: filters.targetType,
        status: filters.status,
      ),
);

final _reportCountsProvider = FutureProvider.autoDispose<List<ReportCount>>(
  (ref) => ref.watch(adminRepositoryProvider).getReportCounts(),
);

/// Panoul unic de moderare: TOATE tipurile de raport într-un singur loc,
/// filtrabile după ce s-a raportat și după status.
///
/// Un panou per tip ar fi însemnat că un moderator trebuie să știe dinainte
/// unde să se uite; aici vede coada întreagă, cu contoare pe filtre.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  // Implicit deschise: e coada de lucru, nu arhiva.
  ReportFilters _filters = const ReportFilters(status: ReportStatus.open);

  void _refresh() {
    ref.invalidate(_reportsProvider(_filters));
    ref.invalidate(_reportCountsProvider);
  }

  /// Câte rapoarte cad pe un tip de țintă, ținând cont de filtrul de status
  /// deja ales - altfel contorul de pe chip ar contrazice lista de dedesubt.
  int _countFor(List<ReportCount> counts, ReportTargetType? targetType) {
    return counts
        .where((c) =>
            (targetType == null || c.targetType == targetType) &&
            (_filters.status == null || c.status == _filters.status))
        .fold(0, (sum, c) => sum + c.count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reports = ref.watch(_reportsProvider(_filters));
    final counts = ref.watch(_reportCountsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminReportsTitle)),
      body: SafeArea(
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _FilterRow(
                label: l10n.adminReportsFilterType,
                chips: [
                  _FilterChipData(
                    label: l10n.adminReportsFilterAll,
                    selected: _filters.targetType == null,
                    count: _countFor(counts, null),
                    onTap: () =>
                        setState(() => _filters = _filters.withTargetType(null)),
                  ),
                  for (final type in ReportTargetType.values)
                    _FilterChipData(
                      label: _targetTypeLabel(context, type),
                      selected: _filters.targetType == type,
                      count: _countFor(counts, type),
                      onTap: () => setState(
                        () => _filters = _filters.withTargetType(type),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _FilterRow(
                label: l10n.adminReportsFilterStatus,
                chips: [
                  _FilterChipData(
                    label: l10n.adminReportsFilterAll,
                    selected: _filters.status == null,
                    onTap: () =>
                        setState(() => _filters = _filters.withStatus(null)),
                  ),
                  for (final status in ReportStatus.values)
                    _FilterChipData(
                      label: reportStatusLabel(context, status),
                      selected: _filters.status == status,
                      onTap: () => setState(
                        () => _filters = _filters.withStatus(status),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: reports.when(
                  loading: () =>
                      const CenteredScrollable(child: CircularProgressIndicator()),
                  error: (_, _) => CenteredScrollable(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.adminReportUpdateError),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return CenteredScrollable(child: Text(l10n.adminNoReports));
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: items.length,
                        itemBuilder: (context, index) => UserReportTile(
                          report: items[index],
                          onChanged: _refresh,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _targetTypeLabel(BuildContext context, ReportTargetType type) {
  final l10n = context.l10n;
  switch (type) {
    case ReportTargetType.user:
      return l10n.adminReportTargetUser;
    case ReportTargetType.listing:
      return l10n.adminReportTargetListing;
    case ReportTargetType.review:
      return l10n.adminReportTargetReview;
    case ReportTargetType.conversation:
      return l10n.adminReportTargetConversation;
    case ReportTargetType.groupPost:
      return l10n.adminReportTargetGroupPost;
    case ReportTargetType.exchange:
      return l10n.adminReportTargetExchange;
  }
}

class _FilterChipData {
  const _FilterChipData({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
}

/// Un rând de filtre cu scroll orizontal - cu șase tipuri de țintă, un `Wrap`
/// ar fi ocupat trei rânduri din ecran înainte de primul raport.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.chips});

  final String label;
  final List<_FilterChipData> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final chip = chips[index];
              return FilterChip(
                label: Text(
                  chip.count != null && chip.count! > 0
                      ? '${chip.label} (${chip.count})'
                      : chip.label,
                ),
                selected: chip.selected,
                onSelected: (_) => chip.onTap(),
              );
            },
          ),
        ),
      ],
    );
  }
}
