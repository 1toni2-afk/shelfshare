import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

/// Ecran de ajutor pentru explicații despre cum funcționează aplicația - XP,
/// trust score, rafturi vs. bibliotecă, cele 3 secțiuni de pe Home, insigne
/// etc.
///
/// Nu-l confunda cu [AboutDevScreen] (care e pentru donații). Aici sunt DOAR
/// explicații de features. Fiecare subiect e într-un `ExpansionTile` colapsat
/// la deschidere: userul explorează în ordine ce-l interesează, restul rămân
/// scanabile ca titluri.
///
/// XP-ul e citit din backend (`gamification.xpRewards`) - dacă valorile se
/// schimbă, ecranul se actualizează singur, nu trebuie să sincronizăm două
/// surse de adevăr.
class AboutAppScreen extends ConsumerWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final gamification =
        auth is AuthAuthenticated ? auth.user.gamification : null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.aboutAppTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _intro(context),
                const SizedBox(height: 16),
                _section(
                  context,
                  icon: Icons.emoji_events_outlined,
                  title: l10n.aboutAppXpTitle,
                  child: _XpExplainer(
                    xpPerLevel: gamification?.xpPerLevel ?? 100,
                    xpRewards: gamification?.xpRewards ?? const {},
                  ),
                ),
                _section(
                  context,
                  icon: Icons.verified_outlined,
                  title: l10n.aboutAppTrustTitle,
                  child: Text(l10n.aboutAppTrustBody, style: _bodyStyle(context)),
                ),
                _section(
                  context,
                  icon: Icons.auto_stories_outlined,
                  title: l10n.aboutAppShelvesTitle,
                  child: Text(l10n.aboutAppShelvesBody, style: _bodyStyle(context)),
                ),
                _section(
                  context,
                  icon: Icons.explore_outlined,
                  title: l10n.aboutAppHomeSectionsTitle,
                  child: Text(l10n.aboutAppHomeSectionsBody, style: _bodyStyle(context)),
                ),
                _section(
                  context,
                  icon: Icons.swap_horiz_outlined,
                  title: l10n.aboutAppExchangesTitle,
                  child: Text(l10n.aboutAppExchangesBody, style: _bodyStyle(context)),
                ),
                _section(
                  context,
                  icon: Icons.workspace_premium_outlined,
                  title: l10n.aboutAppBadgesTitle,
                  child: Text(l10n.aboutAppBadgesBody, style: _bodyStyle(context)),
                ),
                _section(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: l10n.aboutAppChatTitle,
                  child: Text(l10n.aboutAppChatBody, style: _bodyStyle(context)),
                ),
                _section(
                  context,
                  icon: Icons.delete_outline,
                  title: l10n.aboutAppAccountDeletionTitle,
                  child: Text(l10n.aboutAppAccountDeletionBody, style: _bodyStyle(context)),
                ),
                _section(
                  context,
                  icon: Icons.eco_outlined,
                  title: l10n.aboutAppSustainabilityTitle,
                  child: Text(l10n.aboutAppSustainabilityBody, style: _bodyStyle(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.aboutAppIntro,
              style: TextStyle(color: AppColors.foreground, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }

  TextStyle _bodyStyle(BuildContext context) {
    return TextStyle(color: AppColors.foreground, fontSize: 14, height: 1.5);
  }
}

/// Explicație XP - reia formatul din gamification_card ca userii să găsească
/// aceeași reprezentare când sunt curioși în două locuri diferite.
class _XpExplainer extends StatelessWidget {
  const _XpExplainer({required this.xpPerLevel, required this.xpRewards});
  final int xpPerLevel;
  final Map<String, int> xpRewards;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = <String, String>{
      'bookListed': l10n.gamificationXpBookListed,
      'exchangeCompleted': l10n.gamificationXpExchangeCompleted,
      'saleCompleted': l10n.gamificationXpSaleCompleted,
      'reviewWritten': l10n.gamificationXpReviewWritten,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gamificationXpIntro(xpPerLevel),
          style: TextStyle(color: AppColors.foreground, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 12),
        for (final entry in xpRewards.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(labels[entry.key] ?? entry.key)),
                Text(
                  '+${entry.value} XP',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          l10n.gamificationNoMaxLevel,
          style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
        ),
      ],
    );
  }
}
