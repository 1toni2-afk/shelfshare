import 'package:flutter/material.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  static const _tipIcons = [
    Icons.wb_sunny_outlined,
    Icons.storefront_outlined,
    Icons.videocam_outlined,
    Icons.privacy_tip_outlined,
    Icons.star_outline,
    Icons.face_outlined,
    Icons.menu_book_outlined,
    Icons.flag_outlined,
  ];

  static List<(IconData, String, String)> _tips(AppLocalizations l10n) => [
        (_tipIcons[0], l10n.safetyTip1Title, l10n.safetyTip1Desc),
        (_tipIcons[1], l10n.safetyTip2Title, l10n.safetyTip2Desc),
        (_tipIcons[2], l10n.safetyTip3Title, l10n.safetyTip3Desc),
        (_tipIcons[3], l10n.safetyTip4Title, l10n.safetyTip4Desc),
        (_tipIcons[4], l10n.safetyTip5Title, l10n.safetyTip5Desc),
        (_tipIcons[5], l10n.safetyTip6Title, l10n.safetyTip6Desc),
        (_tipIcons[6], l10n.safetyTip7Title, l10n.safetyTip7Desc),
        (_tipIcons[7], l10n.safetyTip8Title, l10n.safetyTip8Desc),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyCenterTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.safetyCenterIntro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            for (final (icon, title, description) in _tips(l10n))
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(icon, color: AppColors.accent),
                  title: Text(title, style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(description),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
