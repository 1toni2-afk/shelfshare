import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/romanian_cities.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/achievements_grid.dart';
import '../../../shared/widgets/profile_qr_dialog.dart';
import '../../../shared/widgets/trust_score_card.dart';
import '../../../shared/widgets/impact_stats_card.dart';
import '../../../shared/widgets/gamification_card.dart';
import 'challenges_widgets.dart';
import '../../../shared/utils/share_link.dart';
import '../../auth/application/auth_controller.dart';
import '../application/profile_controller.dart';
import '../data/feedback_repository.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _sheetOpen = false;

  Future<void> _editProfile(AppUser user) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditProfileSheet(user: user),
    );
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: l10n.profileQrTooltip,
            onPressed: () {
              final userId = state.value?.id;
              if (userId != null) {
                showDialog<void>(
                  context: context,
                  builder: (context) => ProfileQrDialog(userId: userId),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.profileCopyLink,
            onPressed: () {
              final userId = state.value?.id;
              if (userId != null) copyShareLink(context, '/users/$userId');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(profileControllerProvider.notifier).refresh(),
          child: state.when(
            data: (user) => _ProfileContent(
              user: user,
              onEdit: () => _editProfile(user),
            ),
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.profileLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(profileControllerProvider.notifier).refresh(),
                    child: Text(l10n.commonRetry),
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

Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(localeControllerProvider).value;
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
            groupValue: current ?? AppLocale.ro,
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

String _themeModeLabel(BuildContext context, AppThemeMode mode) {
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

Future<void> _showThemePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(themeControllerProvider).value ?? AppThemeMode.system;
  final chosen = await showDialog<AppThemeMode>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.profileDarkModeSection),
      children: [
        for (final mode in AppThemeMode.values)
          RadioListTile<AppThemeMode>(
            title: Text(_themeModeLabel(context, mode)),
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

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        ProfileHeader(
          profileImage: user.profileImage,
          name: user.name,
          username: user.username,
          subtitleLines: [user.email, if (user.city != null) user.city!],
          rating: user.rating,
          booksExchangedCount: user.booksExchangedCount,
          bio: user.bio,
          bioTitle: l10n.profileAboutMe,
        ),
        if (user.trustScore != null) ...[
          const SizedBox(height: 20),
          TrustScoreCard(trustScore: user.trustScore!),
        ],
        if (user.gamification != null) ...[
          const SizedBox(height: 20),
          GamificationCard(stats: user.gamification!),
        ],
        const SizedBox(height: 20),
        const MonthlyChallengesCard(),
        const SizedBox(height: 20),
        const ReadingChallengeCard(),
        if (user.achievements != null && user.achievements!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.profileBadgesTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AchievementsGrid(achievements: user.achievements!),
        ],
        if (user.impactStats != null) ...[
          const SizedBox(height: 20),
          ImpactStatsCard(impactStats: user.impactStats!),
        ],
        if (user.referralCode != null) ...[
          const SizedBox(height: 20),
          _ReferralCard(code: user.referralCode!, count: user.referralCount),
        ],
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.profileMyExchanges),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/exchanges'),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: const Icon(Icons.shield_outlined),
          label: Text(l10n.profileSafetyCenter),
          onPressed: () => context.push('/safety-center'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.help_outline),
          label: Text(l10n.profileHelpCenter),
          onPressed: () => context.push('/help-center'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.leaderboard_outlined),
          label: Text(l10n.profileLeaderboard),
          onPressed: () => context.push('/leaderboard'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.favorite_border),
          label: Text(l10n.profileFavoriteSellers),
          onPressed: () => context.push('/following'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.bar_chart_outlined),
          label: Text(l10n.profileGlobalStats),
          onPressed: () => context.push('/global-stats'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.auto_stories_outlined),
          label: Text(l10n.profileMyBookshelf),
          onPressed: () => context.push('/bookshelf'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.collections_bookmark_outlined),
          label: Text(l10n.collectionsTitle),
          onPressed: () => context.push('/collections'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.dynamic_feed_outlined),
          label: Text(l10n.profileActivityFeed),
          onPressed: () => context.push('/activity-feed'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.compare_arrows_outlined),
          label: Text(l10n.profileSmartMatches),
          onPressed: () => context.push('/smart-matches'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.language_outlined),
          label: Text(l10n.profileLanguage),
          onPressed: () => _showLanguagePicker(context, ref),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(l10n.profileDarkModeSection),
          onPressed: () => _showThemePicker(context, ref),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.feedback_outlined),
          label: Text(l10n.profileSendFeedback),
          onPressed: () => _showFeedbackDialog(context, ref),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onEdit,
          child: Text(l10n.profileEditProfile),
        ),
        if (user.isAdmin) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.shield_outlined),
            label: Text(l10n.profileAdminPanel),
            onPressed: () => context.push('/admin'),
          ),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: Text(l10n.profileLogout),
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

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _usernameController = TextEditingController(text: widget.user.username);
  late final _bioController = TextEditingController(text: widget.user.bio);
  late String? _city = widget.user.city;
  late bool _nameVisible = widget.user.nameVisible;
  late bool _showAcquisitionHistory = widget.user.showAcquisitionHistory;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileControllerProvider.notifier).updateProfile(
            name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            username: _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
            nameVisible: _nameVisible,
            city: _city,
            bio: _bioController.text.trim(),
            showAcquisitionHistory: _showAcquisitionHistory,
          );
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : context.l10n.profileSaveError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.profileSaveError)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.profileEditProfile, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.onboardingLastName),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.profileUsernameLabel,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.onboardingNameVisibleSwitch),
              subtitle: Text(l10n.onboardingUsernameAlwaysVisible),
              value: _nameVisible,
              onChanged: (value) => setState(() => _nameVisible = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _city,
              decoration: InputDecoration(labelText: l10n.profileCityLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.profileNoCity)),
                for (final city in kRomanianCities) DropdownMenuItem(value: city, child: Text(city)),
              ],
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(labelText: l10n.profileAboutMe),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.profileShowAcquisitionHistory),
              subtitle: Text(l10n.profileShowAcquisitionHistorySubtitle),
              value: _showAcquisitionHistory,
              onChanged: (value) => setState(() => _showAcquisitionHistory = value),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
