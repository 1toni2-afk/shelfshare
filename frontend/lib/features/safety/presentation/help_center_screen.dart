import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/data/feedback_repository.dart';

class _FaqGroup {
  const _FaqGroup(this.label, this.items);
  final String label;
  final List<(String, String)> items;
}

class HelpCenterScreen extends ConsumerWidget {
  const HelpCenterScreen({super.key});

  // Grupate pe teme (Milestone 20): schimburi, prețuri, siguranță - în loc de
  // o listă plată care nu mai scalează peste 7 întrebări.
  static List<_FaqGroup> _groups(AppLocalizations l10n) => [
        _FaqGroup(l10n.helpGroupSwapping, [
          (l10n.helpFaq1Question, l10n.helpFaq1Answer),
          (l10n.helpFaq6Question, l10n.helpFaq6Answer),
          (l10n.helpFaq7Question, l10n.helpFaq7Answer),
        ]),
        _FaqGroup(l10n.helpGroupPricing, [
          (l10n.helpFaq3Question, l10n.helpFaq3Answer),
          (l10n.helpFaq4Question, l10n.helpFaq4Answer),
        ]),
        _FaqGroup(l10n.helpGroupSafety, [
          (l10n.helpFaq2Question, l10n.helpFaq2Answer),
          (l10n.helpFaq5Question, l10n.helpFaq5Answer),
        ]),
      ];

  Future<void> _showContactModeratorDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.helpContactModerator),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(hintText: l10n.profileFeedbackHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.commonSubmit),
          ),
        ],
      ),
    );
    if (message != null && message.trim().length >= 3) {
      try {
        await ref.read(feedbackRepositoryProvider).submit(message.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileFeedbackThanks)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileFeedbackError)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groups = _groups(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpCenterTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var g = 0; g < groups.length; g++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                    child: Text(
                      groups[g].label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  for (final (question, answer) in groups[g].items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        // Prima întrebare din prima secțiune stă deschisă -
                        // altfel pagina arată complet goală la prima privire.
                        initiallyExpanded: g == 0 && groups[g].items.first.$1 == question,
                        title: Text(question, style: Theme.of(context).textTheme.titleSmall),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(answer, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.helpStillStuck, style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                l10n.helpCenterFooter,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _showContactModeratorDialog(context, ref),
                          child: Text(l10n.helpContactModerator),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
