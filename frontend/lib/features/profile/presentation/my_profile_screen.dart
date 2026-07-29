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
import '../../../data/models/collection.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/profile_qr_dialog.dart';
import '../../../shared/widgets/trust_score_card.dart';
import '../../../shared/utils/share_link.dart';
import '../../auth/application/auth_controller.dart';
import '../../books/application/my_library_controller.dart';
import '../../collections/data/collections_repository.dart';
import '../application/profile_controller.dart';
import '../data/feedback_repository.dart';
import '../data/profile_repository.dart';

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
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.profileCopyLink,
            onPressed: () {
              final userId = state.value?.id;
              if (userId != null) copyShareLink(context, '/users/$userId');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.profileSettings,
            onPressed: () {
              final user = state.value;
              if (user == null) return;
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (context) => _SettingsSheet(
                  user: user,
                  onEdit: () {
                    Navigator.of(context).pop();
                    _editProfile(user);
                  },
                ),
              );
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

/// Layout compact al profilului propriu (Milestone 11), inspirat de macheta
/// mobilă: header cu avatar + trust score compact în dreapta, o linie de
/// statistici cu bordură, un rând de acțiuni, apoi secțiunile de conținut
/// (challenge, library preview, collections, recent activity). Setările,
/// deconectarea, ștergerea contului și scurtăturile secundare stau într-un
/// bottom sheet accesibil prin iconița „⚙" din AppBar - profilul principal
/// rămâne scurt și scan-abil.
class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        _CompactHeader(user: user),
        const SizedBox(height: 16),
        _StatsRow(user: user),
        const SizedBox(height: 20),
        _PrimaryActions(user: user, onEdit: onEdit),
        const SizedBox(height: 24),
        const _ReadingChallengeMini(),
        const SizedBox(height: 24),
        const _LibraryPreview(),
        const SizedBox(height: 24),
        const _CollectionsPreview(),
        const SizedBox(height: 24),
        const _RecentActivityPreview(),
        // Fallback pentru useri care nu au deschis niciodată setările:
        // avem o mențiune vizuală discretă că restul stă în „⚙".
        const SizedBox(height: 32),
        Center(
          child: Text(
            l10n.profileMoreInSettings,
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Restul acțiunilor secundare care înainte umpleau tot ecranul de profil.
/// Deschis prin iconița „⚙" din AppBar.
class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          Text(l10n.profileSettings, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l10n.profileSettingsSubtitle,
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (user.referralCode != null) ...[
            _ReferralCard(code: user.referralCode!, count: user.referralCount),
            const SizedBox(height: 16),
          ],
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n.profileQrTooltip),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                showDialog<void>(
                  context: context,
                  builder: (context) => ProfileQrDialog(userId: user.id),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.profileMyExchanges),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/exchanges');
              },
            ),
          ),
          _SheetTile(
            icon: Icons.edit_outlined,
            label: l10n.profileEditProfile,
            onTap: onEdit,
          ),
          _SheetTile(
            icon: Icons.language_outlined,
            label: l10n.profileLanguage,
            onTap: () => _showLanguagePicker(context, ref),
          ),
          _SheetTile(
            icon: Icons.dark_mode_outlined,
            label: l10n.profileDarkModeSection,
            onTap: () => _showThemePicker(context, ref),
          ),
          const Divider(height: 24),
          _SheetTile(
              icon: Icons.auto_stories_outlined,
              label: l10n.profileMyBookshelf,
              onTap: () => _navigate(context, '/bookshelf')),
          _SheetTile(
              icon: Icons.collections_bookmark_outlined,
              label: l10n.collectionsTitle,
              onTap: () => _navigate(context, '/collections')),
          _SheetTile(
              icon: Icons.groups_outlined,
              label: l10n.groupsTitle,
              onTap: () => _navigate(context, '/groups')),
          _SheetTile(
              icon: Icons.dynamic_feed_outlined,
              label: l10n.profileActivityFeed,
              onTap: () => _navigate(context, '/activity-feed')),
          _SheetTile(
              icon: Icons.compare_arrows_outlined,
              label: l10n.profileSmartMatches,
              onTap: () => _navigate(context, '/smart-matches')),
          _SheetTile(
              icon: Icons.favorite_border,
              label: l10n.profileFavoriteSellers,
              onTap: () => _navigate(context, '/following')),
          _SheetTile(
              icon: Icons.leaderboard_outlined,
              label: l10n.profileLeaderboard,
              onTap: () => _navigate(context, '/leaderboard')),
          _SheetTile(
              icon: Icons.bar_chart_outlined,
              label: l10n.profileGlobalStats,
              onTap: () => _navigate(context, '/global-stats')),
          _SheetTile(
            icon: Icons.insights_outlined,
            iconColor: user.isPremium ? Colors.amber : null,
            label: l10n.premiumAnalyticsTitle,
            onTap: () => _navigate(context, '/seller-analytics'),
          ),
          const Divider(height: 24),
          _SheetTile(
              icon: Icons.shield_outlined,
              label: l10n.profileSafetyCenter,
              onTap: () => _navigate(context, '/safety-center')),
          _SheetTile(
              icon: Icons.help_outline,
              label: l10n.profileHelpCenter,
              onTap: () => _navigate(context, '/help-center')),
          _SheetTile(
              icon: Icons.feedback_outlined,
              label: l10n.profileSendFeedback,
              onTap: () => _showFeedbackDialog(context, ref)),
          _SheetTile(
              icon: Icons.android,
              label: l10n.profilePreRegister,
              onTap: () => _navigate(context, '/pre-register')),
          if (user.isAdmin) ...[
            const Divider(height: 24),
            _SheetTile(
                icon: Icons.admin_panel_settings_outlined,
                label: l10n.profileAdminPanel,
                onTap: () => _navigate(context, '/admin')),
          ],
          const Divider(height: 24),
          _SheetTile(
            icon: Icons.logout,
            label: l10n.profileLogout,
            iconColor: AppColors.destructive,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 12),
          _DeleteAccountSection(user: user),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static void _navigate(BuildContext context, String path) {
    Navigator.of(context).pop();
    context.push(path);
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

/// Element compact folosit în settings sheet - listă densă cu iconă, label și
/// chevron. Înlocuiește 15+ `OutlinedButton.icon` din vechiul layout.
class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor ?? AppColors.mutedForeground),
      title: Text(label),
      trailing: Icon(Icons.chevron_right, color: AppColors.mutedForeground),
      onTap: onTap,
    );
  }
}

/// Header compact: avatar (56dp) + nume/username·oraș pe centru + trust score
/// compact pe dreapta. Trust score-ul afișează doar numărul + cuvânt „trust";
/// tap deschide un dialog cu detaliile (aceleași chip-uri de pe cardul mare).
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.user});
  final AppUser user;

  void _openTrustDetails(BuildContext context) {
    if (user.trustScore == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TrustScoreCard(trustScore: user.trustScore!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user.name?.trim().isNotEmpty == true ? user.name! : user.email;
    final subtitleParts = [
      if (user.username != null) '@${user.username}',
      if (user.city != null && user.city!.isNotEmpty) user.city!,
    ];
    final trust = user.trustScore?.score;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.muted,
          backgroundImage: user.profileImage != null
              ? NetworkImage(user.profileImage!)
              : null,
          child: user.profileImage == null
              ? Icon(Icons.person, color: AppColors.mutedForeground, size: 32)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.isEmailVerified) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified, size: 16, color: AppColors.accent),
                  ],
                ],
              ),
              if (subtitleParts.isNotEmpty)
                Text(
                  subtitleParts.join(' · '),
                  style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (trust != null)
          InkWell(
            onTap: () => _openTrustDetails(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  Text(
                    '$trust',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'trust',
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Linia orizontală cu 3 statistici (books / swaps / rating), separată printr-o
/// linie subțire jos, ca reper vizual pentru finalul header-ului.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _stat(context, user.booksSharedCount.toString(), l10n.profileStatBooks),
          const SizedBox(width: 24),
          _stat(context, user.booksExchangedCount.toString(), l10n.profileStatSwaps),
          const SizedBox(width: 24),
          _stat(
            context,
            user.rating > 0 ? user.rating.toStringAsFixed(1) : '—',
            l10n.profileStatRating,
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Row(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
      ],
    );
  }
}

/// Rândul de acțiuni principale de sub statistici. Pentru profilul propriu:
/// Editează profil (buton primar lat) + QR (icon) + Share (icon).
class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: onEdit,
            child: Text(l10n.profileEditProfile),
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(
          context: context,
          icon: Icons.qr_code_2,
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => ProfileQrDialog(userId: user.id),
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(
          context: context,
          icon: Icons.share_outlined,
          onTap: () => copyShareLink(context, '/users/${user.id}'),
        ),
      ],
    );
  }

  Widget _iconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

/// Reading challenge condensat: „N challenge · x/goal" + progress bar subțire.
/// Ascuns dacă userul nu a setat obiectivul anual.
class _ReadingChallengeMini extends ConsumerWidget {
  const _ReadingChallengeMini();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_readingChallengeProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (challenge) {
        if (challenge.goal == null || challenge.goal == 0) return const SizedBox.shrink();
        final progress = (challenge.progress / challenge.goal!).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${challenge.year} challenge',
                  style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${challenge.progress} / ${challenge.goal}',
                  style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.muted,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Preview library: titlu + „N available" + grid 5 coloane cu primele 4
/// coperte + tile „+N" (câte mai sunt).
class _LibraryPreview extends ConsumerWidget {
  const _LibraryPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myLibraryControllerProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        // Doar cărțile „vii" (nu emptied shelves, nu trash) apar în preview -
        // afișăm inventarul curent.
        final active = books.where((b) => !b.permanentlyTransferred).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        final visible = active.take(4).toList();
        final rest = active.length - visible.length;
        return InkWell(
          onTap: () => context.push('/library'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.libraryTitle, style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    l10n.profileLibraryAvailable(active.length),
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileW = (constraints.maxWidth - 4 * 7) / 5;
                  return Row(
                    children: [
                      for (final b in visible) ...[
                        SizedBox(
                          width: tileW,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: BookCover(url: b.book.coverUrl, borderRadius: 5),
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      SizedBox(
                        width: tileW,
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              rest > 0 ? '+$rest' : '—',
                              style: TextStyle(
                                color: AppColors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Preview collections: chip-uri „nume · count". Ascuns dacă nu are colecții.
class _CollectionsPreview extends ConsumerWidget {
  const _CollectionsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(_myCollectionsPreviewProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (collections) {
        if (collections.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.collectionsTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final c in collections.take(6))
                  InkWell(
                    onTap: () => context.push('/collections/${c.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${c.name} · ${c.itemCount}',
                        style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// „Recent activity": ultimele acțiuni ale userului derivate din biblioteca
/// proprie (primele 4 cărți adăugate). Format compact stil twitter-timeline:
/// text stânga + timp relativ dreapta.
class _RecentActivityPreview extends ConsumerWidget {
  const _RecentActivityPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myLibraryControllerProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        final events = books.take(4).toList();
        if (events.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileRecentActivity,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final b in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${l10n.profileActivityAdded} ',
                          style: TextStyle(color: AppColors.mutedForeground, fontSize: 12.5),
                          children: [
                            TextSpan(
                              text: b.book.title,
                              style: TextStyle(color: AppColors.foreground),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _relativeAge(b.createdAt),
                      style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _relativeAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }
}

// Providers dedicati preview-urilor (evită dependența pe alte ecrane).
final _readingChallengeProvider = FutureProvider<ReadingChallenge>((ref) {
  return ref.watch(profileRepositoryProvider).getReadingChallenge();
});
final _myCollectionsPreviewProvider = FutureProvider<List<BookCollection>>((ref) {
  return ref.watch(collectionsRepositoryProvider).getMine();
});

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

/// Secțiunea de ștergere cont din josul profilului. Două stări:
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
