import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/profile_qr_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../application/profile_controller.dart';
import '../data/feedback_repository.dart';
import '../data/profile_repository.dart';

/// Setările contului, ca rută (`/profile/settings`) în loc de bottom sheet.
/// Vezi comentariul din [EditProfileScreen] pentru motivul schimbării: back-ul
/// de sistem trebuie să întoarcă un pas, nu să sară din stivă.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(profileControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileSettings)),
      body: SafeArea(
        child: user == null
            ? const CenteredScrollable(child: CircularProgressIndicator())
            // Centrarea + limita de 560px se fac ACUM în interiorul ListView-ului
            // (vezi _SettingsList), ca lista să ocupe toată lățimea și scroll-ul
            // cu rotița să meargă oriunde pe pagină, nu doar peste coloană.
            : _SettingsList(user: user),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // ListView pe toată lățimea viewport-ului (fără ConstrainedBox în jur) =>
    // scroll cu rotița funcționează oriunde pe pagină, nu doar peste coloana de
    // 560px. Conținutul rămâne centrat și îngustat prin Center + ConstrainedBox
    // de mai jos, într-un singur Column. (Milestone 18)
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.profileSettingsSubtitle,
                    style:
                        TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
        // Donațiile stau sus, ca prim element vizibil: aplicația e găzduită pe
        // un server personal, deci e singura sursă de finanțare.
        _KeepAliveCard(onTap: () => context.push('/profile/about-dev')),
        const SizedBox(height: 16),
        // Codul de referral e ascuns deocamdată (Milestone 18) - programul nu e
        // activ. Cardul rămâne în cod (`_ReferralCard`) ca să poată fi reactivat
        // ușor, reintroducând blocul de mai jos.
        // if (user.referralCode != null) ...[
        //   _ReferralCard(code: user.referralCode!, count: user.referralCount),
        //   const SizedBox(height: 16),
        // ],
        Card(
          child: ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: Text(l10n.profileQrTooltip),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => ProfileQrDialog(userId: user.id),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.profileMyExchanges),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/exchanges'),
          ),
        ),
        _SettingsTile(
          icon: Icons.edit_outlined,
          label: l10n.profileEditProfile,
          onTap: () => context.push('/profile/edit'),
        ),
        _SettingsTile(
          icon: Icons.language_outlined,
          label: l10n.profileLanguage,
          trailingLabel: ref.watch(effectiveLocaleProvider).label,
          onTap: () => showLanguagePicker(context, ref),
        ),
        _SettingsTile(
          icon: Icons.dark_mode_outlined,
          label: l10n.profileDarkModeSection,
          trailingLabel: themeModeLabel(
            context,
            ref.watch(themeControllerProvider).value ?? AppThemeMode.system,
          ),
          onTap: () => showThemePicker(context, ref),
        ),
        const Divider(height: 24),
        _SettingsTile(
            icon: Icons.auto_stories_outlined,
            label: l10n.profileMyBookshelf,
            onTap: () => context.push('/bookshelf')),
        _SettingsTile(
            icon: Icons.collections_bookmark_outlined,
            label: l10n.collectionsTitle,
            onTap: () => context.push('/collections')),
        _SettingsTile(
            icon: Icons.groups_outlined,
            label: l10n.groupsTitle,
            onTap: () => context.push('/groups')),
        _SettingsTile(
            icon: Icons.dynamic_feed_outlined,
            label: l10n.profileActivityFeed,
            onTap: () => context.push('/activity-feed')),
        _SettingsTile(
            icon: Icons.compare_arrows_outlined,
            label: l10n.profileSmartMatches,
            onTap: () => context.push('/smart-matches')),
        _SettingsTile(
            icon: Icons.favorite_border,
            label: l10n.profileFavoriteSellers,
            onTap: () => context.push('/following')),
        _SettingsTile(
            icon: Icons.leaderboard_outlined,
            label: l10n.profileLeaderboard,
            onTap: () => context.push('/leaderboard')),
        _SettingsTile(
            icon: Icons.bar_chart_outlined,
            label: l10n.profileGlobalStats,
            onTap: () => context.push('/global-stats')),
        _SettingsTile(
          icon: Icons.insights_outlined,
          iconColor: user.isPremium ? AppColors.warning : null,
          label: l10n.premiumAnalyticsTitle,
          onTap: () => context.push('/seller-analytics'),
        ),
        const Divider(height: 24),
        _SettingsTile(
            icon: Icons.shield_outlined,
            label: l10n.profileSafetyCenter,
            onTap: () => context.push('/safety-center')),
        _SettingsTile(
            icon: Icons.help_outline,
            label: l10n.profileHelpCenter,
            onTap: () => context.push('/help-center')),
        _SettingsTile(
            icon: Icons.person_outline,
            label: l10n.aboutDevTitle,
            onTap: () => context.push('/profile/about-dev')),
        _SettingsTile(
            icon: Icons.feedback_outlined,
            label: l10n.profileSendFeedback,
            onTap: () => _showFeedbackDialog(context, ref)),
        _SettingsTile(
            icon: Icons.android,
            label: l10n.profilePreRegister,
            onTap: () => context.push('/pre-register')),
        if (user.isAdmin) ...[
          const Divider(height: 24),
          _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              label: l10n.profileAdminPanel,
              onTap: () => context.push('/admin')),
        ],
        const Divider(height: 24),
        _SettingsTile(
          icon: Icons.logout,
          label: l10n.profileLogout,
          iconColor: AppColors.destructive,
          onTap: () => ref.read(authControllerProvider.notifier).logout(),
        ),
        const SizedBox(height: 12),
        _DeleteAccountSection(user: user),
        const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileSendFeedback),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.profileFeedbackThanks)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.profileFeedbackError)));
        }
      }
    }
  }
}

/// Cardul de donații - „Keep the app alive". Duce în „About dev", unde stă
/// butonul de cafea.
class _KeepAliveCard extends StatelessWidget {
  const _KeepAliveCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: AppColors.accent.withValues(alpha: 0.10),
      child: ListTile(
        leading: const Text('☕', style: TextStyle(fontSize: 22)),
        title: Text(
          l10n.profileKeepAlive,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          l10n.profileKeepAliveSubtitle,
          style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Rând compact de setare: iconă, label, valoarea curentă (opțional) și chevron.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.trailingLabel,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor ?? AppColors.mutedForeground),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingLabel != null)
            Text(
              trailingLabel!,
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
            ),
          Icon(Icons.chevron_right, color: AppColors.mutedForeground),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Selectorul de limbă - folosit atât din Setări, cât și din ecranul de login.
/// Bifa arată limba folosită efectiv (vezi [effectiveLocaleProvider]), nu
/// „Română" implicit peste o aplicație care rula în limba telefonului.
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(effectiveLocaleProvider);
  final chosen = await showDialog<AppLocale>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.profileLanguage),
      children: [
        for (final locale in AppLocale.values)
          RadioListTile<AppLocale>(
            title: Text(locale.label),
            value: locale,
            // ignore: deprecated_member_use
            groupValue: current,
            // ignore: deprecated_member_use
            onChanged: (value) => Navigator.of(context).pop(value),
          ),
      ],
    ),
  );
  if (chosen != null) {
    await ref.read(localeControllerProvider.notifier).setLocale(chosen);
  }
}

String themeModeLabel(BuildContext context, AppThemeMode mode) {
  final l10n = context.l10n;
  switch (mode) {
    case AppThemeMode.system:
      return l10n.profileThemeSystem;
    case AppThemeMode.light:
      return l10n.profileThemeLight;
    case AppThemeMode.dark:
      return l10n.profileThemeDark;
  }
}

Future<void> showThemePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(themeControllerProvider).value ?? AppThemeMode.system;
  final chosen = await showDialog<AppThemeMode>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.profileDarkModeSection),
      children: [
        for (final mode in AppThemeMode.values)
          RadioListTile<AppThemeMode>(
            title: Text(themeModeLabel(context, mode)),
            value: mode,
            // ignore: deprecated_member_use
            groupValue: current,
            // ignore: deprecated_member_use
            onChanged: (value) => Navigator.of(context).pop(value),
          ),
      ],
    ),
  );
  if (chosen != null) {
    await ref.read(themeControllerProvider.notifier).setThemeMode(chosen);
  }
}

// Ascuns temporar în Milestone 18 (vezi mai sus) - păstrat pentru reactivare.
// ignore: unused_element
class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.code, required this.count});
  final String code;
  final int count;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.profileReferralCopied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileReferralTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.profileReferralSubtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      code,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => _copyCode(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileReferralCountLabel(count),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Secțiunea de ștergere cont. Două stări:
/// (a) neprogramat - buton „Șterge contul" cu confirm dialog care explică
///     fereastra de 15 zile,
/// (b) programat - banner de avertisment cu data efectivă + buton „Anulează".
/// Cerință Google Play (Data safety): trebuie să existe cale in-app pentru
/// ștergerea contului, nu doar formular web.
class _DeleteAccountSection extends ConsumerStatefulWidget {
  const _DeleteAccountSection({required this.user});
  final AppUser user;

  @override
  ConsumerState<_DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<_DeleteAccountSection> {
  bool _busy = false;

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge contul'),
        content: const Text(
          'Contul tău și toate datele asociate (cărți, schimburi, mesaje, wishlist) '
          'vor fi șterse definitiv după 15 zile. Poți anula oricând în această perioadă '
          'reintrând în cont și apăsând „Anulează ștergerea".\n\n'
          'Vrei să continui?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge contul'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).requestAccountDeletion();
      await ref.read(profileControllerProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ștergerea contului a fost programată')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut programa ștergerea. Încearcă din nou.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).cancelAccountDeletion();
      await ref.read(profileControllerProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ștergerea a fost anulată')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut anula. Încearcă din nou.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduledAt = widget.user.deletionScheduledAt;
    if (scheduledAt != null) {
      final daysLeft = scheduledAt.difference(DateTime.now()).inDays;
      final dateStr = '${scheduledAt.day.toString().padLeft(2, '0')}.'
          '${scheduledAt.month.toString().padLeft(2, '0')}.${scheduledAt.year}';
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.destructive.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.destructive),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contul tău va fi șters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.destructive,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Data ștergerii: $dateStr'
              '${daysLeft > 0 ? " (peste $daysLeft zile)" : " (astăzi)"}.\n'
              'Poți anula acum și contul va rămâne activ.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _cancelDeletion,
                child: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Anulează ștergerea'),
              ),
            ),
          ],
        ),
      );
    }

    return TextButton(
      onPressed: _busy ? null : _requestDeletion,
      style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
      child: const Text('Șterge contul'),
    );
  }
}
