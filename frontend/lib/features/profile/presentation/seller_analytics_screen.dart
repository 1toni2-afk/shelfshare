import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/profile_repository.dart';

final _sellerAnalyticsProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getSellerAnalytics();
});

/// "Advanced Analytics" (Premium) - statistici de vânzător, calculate din
/// date deja existente (vizualizări, oferte) - vezi getSellerAnalytics.
class SellerAnalyticsScreen extends ConsumerWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_sellerAnalyticsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premiumAnalyticsTitle)),
      body: SafeArea(
        child: async.when(
          data: (stats) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(label: l10n.premiumAnalyticsTotalListings, value: '${stats.totalListings}'),
              _StatCard(label: l10n.premiumAnalyticsTotalViews, value: '${stats.totalViews}'),
              _StatCard(label: l10n.premiumAnalyticsOffersReceived, value: '${stats.totalOffersReceived}'),
              _StatCard(
                label: l10n.premiumAnalyticsConversionRate,
                value: '${(stats.conversionRate * 100).toStringAsFixed(0)}%',
              ),
              _StatCard(
                label: l10n.premiumAnalyticsRevenue,
                value: l10n.priceLei(stats.totalRevenue.toStringAsFixed(0)),
              ),
              const SizedBox(height: 16),
              if (stats.topListingsByViews.isNotEmpty) ...[
                Text(l10n.premiumAnalyticsTopListings, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final listing in stats.topListingsByViews)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('${listing.views}'),
                  ),
              ],
            ],
          ),
          loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
          error: (error, _) {
            final isForbidden = error is DioException && error.response?.statusCode == 403;
            return CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, size: 48, color: AppColors.mutedForeground),
                  const SizedBox(height: 12),
                  Text(
                    isForbidden ? l10n.premiumAnalyticsLocked : l10n.premiumAnalyticsLoadError,
                    textAlign: TextAlign.center,
                  ),
                  if (!isForbidden) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(_sellerAnalyticsProvider),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
