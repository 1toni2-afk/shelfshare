import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../data/models/user.dart';

/// "Money Saved" / "Total Value of Books Exchanged" / "Estimated CO2 Saved" -
/// vezi ImpactStats în data/models/user.dart pentru sursa exactă a
/// numerelor și limitările lor. Ascuns complet dacă userul nu are încă
/// nicio valoare (cont nou, fără schimburi/vânzări finalizate).
class ImpactStatsCard extends StatelessWidget {
  const ImpactStatsCard({super.key, required this.impactStats});
  final ImpactStats impactStats;

  bool get _hasAnyValue =>
      impactStats.totalValueExchanged > 0 || impactStats.moneySaved > 0 || impactStats.co2SavedKg > 0;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyValue) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.impactStatsTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (impactStats.totalValueExchanged > 0)
                  Chip(
                    avatar: const Icon(Icons.swap_horizontal_circle_outlined, size: 16),
                    label: Text(
                      '${l10n.impactStatsTotalValue}: ${l10n.priceLei(impactStats.totalValueExchanged.toStringAsFixed(0))}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (impactStats.moneySaved > 0)
                  Chip(
                    avatar: const Icon(Icons.savings_outlined, size: 16),
                    label: Text(
                      '${l10n.impactStatsMoneySaved}: ${l10n.priceLei(impactStats.moneySaved.toStringAsFixed(0))}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (impactStats.co2SavedKg > 0)
                  Chip(
                    avatar: const Icon(Icons.eco_outlined, size: 16),
                    label: Text(
                      '${l10n.impactStatsCo2Saved}: ${l10n.impactStatsCo2Value(impactStats.co2SavedKg.toStringAsFixed(1))}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
