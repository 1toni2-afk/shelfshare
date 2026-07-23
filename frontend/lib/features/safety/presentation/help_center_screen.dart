import 'package:flutter/material.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static List<(String, String)> _faqs(AppLocalizations l10n) => [
        (l10n.helpFaq1Question, l10n.helpFaq1Answer),
        (l10n.helpFaq2Question, l10n.helpFaq2Answer),
        (l10n.helpFaq3Question, l10n.helpFaq3Answer),
        (l10n.helpFaq4Question, l10n.helpFaq4Answer),
        (l10n.helpFaq5Question, l10n.helpFaq5Answer),
        (l10n.helpFaq6Question, l10n.helpFaq6Answer),
        (l10n.helpFaq7Question, l10n.helpFaq7Answer),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpCenterTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (question, answer) in _faqs(l10n))
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(question, style: Theme.of(context).textTheme.titleSmall),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              l10n.helpCenterFooter,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
