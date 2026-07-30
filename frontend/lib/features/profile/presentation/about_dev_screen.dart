import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/support_links.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';

/// „About dev" + donații. Ecran-rută (nu dialog) ca back-ul de sistem să se
/// comporte previzibil: Setări → About dev → back întoarce în Setări.
///
/// Butonul „Keep the app alive" din Setări duce direct aici, iar de aici se
/// deschide platforma de donații: PayPal pe web, Buy Me a Coffee pe mobil
/// (până la integrarea Google Play Billing - vezi SupportLinks).
class AboutDevScreen extends StatelessWidget {
  const AboutDevScreen({super.key});

  Future<void> _openDonation(BuildContext context) async {
    final url = Uri.parse(kIsWeb ? SupportLinks.paypal : SupportLinks.buyMeACoffee);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aboutDevOpenError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutDevTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        child: Icon(Icons.code, color: AppColors.accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(l10n.aboutDevHeadline, style: theme.textTheme.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final paragraph in [
                    l10n.aboutDevBodyWho,
                    l10n.aboutDevBodyWhy,
                    l10n.aboutDevBodyHosting,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        paragraph,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text('☕', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.aboutDevSupportTitle,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.aboutDevSupportSubtitle,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedForeground, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => _openDonation(context),
                            icon: const Icon(Icons.local_cafe_outlined, size: 18),
                            label: Text(l10n.aboutDevCoffeeButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      SupportLinks.contactEmail,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedForeground),
                    ),
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
