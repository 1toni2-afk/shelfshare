import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_models.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_controller.dart';

/// „Cum folosesc userii aplicația" - panou de admin, doar pentru tine, deci
/// textele stau în română direct în cod (ca la ecranul de scor de anunț), fără
/// să umple cele patru fișiere ARB cu chei pe care nu le vede niciun user.
///
/// Două jumătăți, fiindcă răspund la întrebări diferite:
///  - seria pe zile: „se folosește mai mult sau mai puțin decât săptămâna
///    trecută", cu o metrică selectabilă;
///  - adopția: „câți useri au folosit vreodată funcția X", adică unde se
///    pierde lumea.
class AdminUsageScreen extends ConsumerStatefulWidget {
  const AdminUsageScreen({super.key});

  @override
  ConsumerState<AdminUsageScreen> createState() => _AdminUsageScreenState();
}

class _AdminUsageScreenState extends ConsumerState<AdminUsageScreen> {
  int _days = 30;

  static const _windows = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminUsageStatsProvider(_days));

    return Scaffold(
      appBar: AppBar(title: const Text('Cum e folosită aplicația')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminUsageStatsProvider(_days)),
          child: async.when(
            data: (stats) => _Content(
              stats: stats,
              days: _days,
              windows: _windows,
              onDaysChanged: (value) => setState(() => _days = value),
            ),
            loading: () =>
                const CenteredScrollable(child: CircularProgressIndicator()),
            error: (_, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.adminLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(adminUsageStatsProvider(_days)),
                    child: Text(context.l10n.commonRetry),
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

class _Content extends StatefulWidget {
  const _Content({
    required this.stats,
    required this.days,
    required this.windows,
    required this.onDaysChanged,
  });

  final UsageStats stats;
  final int days;
  final List<int> windows;
  final ValueChanged<int> onDaysChanged;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  UsageSeries _series = UsageSeries.activeUsers;

  static const _seriesLabels = {
    UsageSeries.activeUsers: 'Useri activi',
    UsageSeries.actions: 'Interacțiuni',
    UsageSeries.newUsers: 'Conturi noi',
    UsageSeries.listings: 'Anunțuri',
    UsageSeries.swipes: 'Swipe-uri',
    UsageSeries.searches: 'Căutări',
    UsageSeries.messages: 'Mesaje',
    UsageSeries.offers: 'Oferte',
    UsageSeries.exchanges: 'Cereri de schimb',
  };

  /// Cheia din `totals` care corespunde fiecărei serii. `activeUsers` lipsește
  /// dinadins: un total de useri activi pe fereastră nu se poate aduna din
  /// zile (același om apare în mai multe), backendul întoarce vârful.
  static const _totalKeys = {
    UsageSeries.actions: 'actions',
    UsageSeries.newUsers: 'newUsers',
    UsageSeries.listings: 'listings',
    UsageSeries.swipes: 'swipes',
    UsageSeries.searches: 'searches',
    UsageSeries.messages: 'messages',
    UsageSeries.offers: 'offers',
    UsageSeries.exchanges: 'exchanges',
  };

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final window in widget.windows)
              ChoiceChip(
                label: Text('$window zile'),
                selected: widget.days == window,
                showCheckmark: false,
                onSelected: (_) => widget.onDaysChanged(window),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!stats.logAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Jurnalul de activitate nu are fișiere în fereastra asta, deci '
              '„useri activi" și „interacțiuni" apar ca zero. Restul măsurilor '
              'vin din baza de date și sunt corecte.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.warning),
            ),
          ),
        _TotalsGrid(stats: stats),
        const SizedBox(height: 24),
        Text('Evoluție pe zile', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final series in UsageSeries.values)
              ChoiceChip(
                label: Text(_seriesLabels[series]!),
                selected: _series == series,
                showCheckmark: false,
                onSelected: (_) => setState(() => _series = series),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _UsageChart(days: stats.days, series: _series),
        const SizedBox(height: 8),
        Text(
          _summaryLine(stats),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 24),
        Text('Adopție', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Câți useri au folosit funcția măcar o dată, din totalul de '
          '${stats.adoption.totalUsers}.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        _AdoptionBars(adoption: stats.adoption),
        const SizedBox(height: 24),
        Text('Interacțiuni pe tip', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Din jurnalul de activitate, pe fereastra selectată.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        if (stats.byAction.isEmpty)
          Text(
            'Nicio interacțiune înregistrată.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          )
        else
          for (final entry in stats.byAction)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(entry.action)),
                  Text(
                    '${entry.count}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _summaryLine(UsageStats stats) {
    final key = _totalKeys[_series];
    if (key == null) {
      final peak = stats.totals['peakActiveUsers'] ?? 0;
      return 'Maxim $peak useri activi într-o zi.';
    }
    return 'Total pe fereastră: ${stats.totals[key] ?? 0}.';
  }
}

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.stats});
  final UsageStats stats;

  @override
  Widget build(BuildContext context) {
    final totals = stats.totals;
    final tiles = <(String, int)>[
      ('Vârf useri activi/zi', totals['peakActiveUsers'] ?? 0),
      ('Conturi noi', totals['newUsers'] ?? 0),
      ('Anunțuri postate', totals['listings'] ?? 0),
      ('Swipe-uri Book Match', totals['swipes'] ?? 0),
      ('Căutări', totals['searches'] ?? 0),
      ('Mesaje', totals['messages'] ?? 0),
      ('Oferte', totals['offers'] ?? 0),
      ('Cereri de schimb', totals['exchanges'] ?? 0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Două coloane pe telefon, patru pe ecran lat - aceleași praguri ca
        // restul grilelor din panou.
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            for (final (label, value) in tiles)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$value',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.days, required this.series});
  final List<UsageDay> days;
  final UsageSeries series;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text(
        'Nu avem încă date.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.mutedForeground),
      );
    }

    final values = days.map((day) => day.valueFor(series)).toList();
    final maxValue = values.fold<int>(0, (max, v) => v > max ? v : max);
    // Axa nu poate avea maximul 0 (fl_chart desenează atunci o zonă degenerată)
    // și nici un maxim egal cu valoarea de vârf, care ar lipi linia de plafon.
    final top = (maxValue == 0 ? 1 : maxValue) * 1.2;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: top,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  if (value != meta.max && value != meta.min && value % 1 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                // O etichetă la fiecare a n-a zi: la 90 de zile, o etichetă pe
                // zi ar fi o dungă neagră.
                interval: (days.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  // „09-03" din „2026-09-03" - anul e același pe toată
                  // fereastra și n-ar face decât să lățească eticheta.
                  final label = days[index].date.substring(5);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i].toDouble()),
              ],
              isCurved: false,
              color: AppColors.accent,
              barWidth: 2,
              dotData: FlDotData(show: days.length <= 31),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptionBars extends StatelessWidget {
  const _AdoptionBars({required this.adoption});
  final UsageAdoption adoption;

  @override
  Widget build(BuildContext context) {
    final total = adoption.totalUsers;
    final rows = <(String, int)>[
      ('Au pus un anunț', adoption.withListing),
      ('Au dat swipe în Book Match', adoption.withSwipe),
      ('Au ceva pe raft', adoption.withShelf),
      ('Au ceva pe wishlist', adoption.withWishlist),
      ('Au trimis un mesaj', adoption.withMessage),
    ];

    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      total == 0
                          ? '$value'
                          : '$value (${(value * 100 / total).round()}%)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : (value / total).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
