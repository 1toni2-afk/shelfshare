import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/store.dart';

/// Cardul „Despre magazin" de pe profilul unui anticariat/librărie.
///
/// Program, adresă și politica de livrare sunt exact ce vrea să știe cineva
/// înainte să scrie unui magazin - la un user obișnuit n-are ce căuta, deci
/// cardul apare doar când profilul chiar are date de magazin.
class StoreInfoCard extends StatelessWidget {
  const StoreInfoCard({super.key, required this.profile});

  final StoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final rows = <(IconData, String, String)>[
      if (profile.openingHours != null) (Icons.schedule_outlined, l10n.storeHours, profile.openingHours!),
      if (profile.deliveryPolicy != null)
        (Icons.local_shipping_outlined, l10n.storeDelivery, profile.deliveryPolicy!),
      if (profile.address != null) (Icons.place_outlined, l10n.storeAddress, profile.address!),
      if (profile.phone != null) (Icons.phone_outlined, l10n.storePhone, profile.phone!),
      if (profile.website != null) (Icons.public, l10n.storeWebsite, profile.website!),
    ];

    // Nimic de spus în afară de nume: cardul ar fi un chenar gol.
    if (rows.isEmpty && (profile.description == null || profile.description!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(l10n.storeSectionTitle, style: theme.textTheme.titleSmall),
              ],
            ),
            if (profile.description != null && profile.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(profile.description!, style: theme.textTheme.bodySmall),
            ],
            for (final (icon, label, value) in rows) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: AppColors.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                        Text(value, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Insigna „Magazin" de lângă numele unui cont de anticariat.
class StoreBadge extends StatelessWidget {
  const StoreBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.storeBadge,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}
