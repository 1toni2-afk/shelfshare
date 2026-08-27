import 'package:flutter/material.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Ecran static „Roadmap" - ce funcții sunt deja live și ce urmează. Numele
/// rămâne „Roadmap" netradus în toate limbile (cerință explicită), doar
/// conținutul cardurilor e localizat.
class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      _RoadmapItem(
        icon: Icons.menu_book_outlined,
        title: l10n.roadmapBookOfMonthTitle,
        body: l10n.roadmapBookOfMonthBody,
        live: true,
      ),
      _RoadmapItem(
        icon: Icons.event_outlined,
        title: l10n.roadmapUpcomingReleasesTitle,
        body: l10n.roadmapUpcomingReleasesBody,
        live: true,
      ),
      _RoadmapItem(
        icon: Icons.card_giftcard_outlined,
        title: l10n.roadmapGiveawayTitle,
        body: l10n.roadmapGiveawayBody,
        live: false,
      ),
      _RoadmapItem(
        icon: Icons.storefront_outlined,
        title: l10n.roadmapBookstoreIntegrationsTitle,
        body: l10n.roadmapBookstoreIntegrationsBody,
        live: false,
      ),
      _RoadmapItem(
        icon: Icons.payments_outlined,
        title: l10n.roadmapPaymentsTitle,
        body: l10n.roadmapPaymentsBody,
        live: false,
      ),
      _RoadmapItem(
        icon: Icons.sync_outlined,
        title: l10n.roadmapGoodreadsImportTitle,
        body: l10n.roadmapGoodreadsImportBody,
        live: false,
      ),
      _RoadmapItem(
        icon: Icons.auto_awesome_outlined,
        title: l10n.roadmapAiRecommendationsTitle,
        body: l10n.roadmapAiRecommendationsBody,
        live: false,
      ),
    ];

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Roadmap')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, color: AppColors.accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.roadmapSubtitle,
                          style: TextStyle(
                              color: AppColors.foreground, fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final item in items) _RoadmapCard(item: item, l10n: l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoadmapItem {
  const _RoadmapItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.live,
  });

  final IconData icon;
  final String title;
  final String body;

  /// true = funcția e deja disponibilă în aplicație; false = planificată.
  final bool live;
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.item, required this.l10n});
  final _RoadmapItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: AppColors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      _StatusBadge(live: item.live, l10n: l10n),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    style: TextStyle(
                        color: AppColors.mutedForeground, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.live, required this.l10n});
  final bool live;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = live ? AppColors.success : AppColors.mutedForeground;
    final label = live ? l10n.roadmapStatusLive : l10n.roadmapStatusPlanned;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
