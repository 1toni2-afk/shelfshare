import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';

/// Antetul comun oricărui ecran de profil (al meu sau public): avatar
/// compact (56dp), nume + username·oraș pe un rând, trust score/premium în
/// dreapta. Randat de my_profile_screen.dart (varianta editabilă, cu tap pe
/// avatar) și public_profile_screen.dart (varianta read-only) ca să nu mai
/// diveargă vizual (Milestone 19).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profileImage,
    required this.name,
    this.username,
    this.city,
    this.isVerified = false,
    this.isPremium = false,
    this.avatarLoading = false,
    this.avatarBadge,
    this.onAvatarTap,
    this.trailing,
  });

  final String? profileImage;
  final String? name;
  final String? username;
  final String? city;
  final bool isVerified;
  final bool isPremium;
  /// Afișează un spinner peste avatar (ex. în timpul unui upload de poză).
  final bool avatarLoading;
  /// Widget mic ancorat în colțul din dreapta-jos al avatarului (ex. iconița
  /// de cameră care indică faptul că avatarul se poate schimba).
  final Widget? avatarBadge;
  final VoidCallback? onAvatarTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName = name?.trim().isNotEmpty == true ? name! : l10n.commonUnknownUser;
    final subtitleParts = [
      if (username != null) '@$username',
      if (city != null && city!.trim().isNotEmpty) city!,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.muted,
                backgroundImage: profileImage != null ? NetworkImage(profileImage!) : null,
                child: avatarLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (profileImage == null
                        ? Icon(Icons.person, color: AppColors.mutedForeground, size: 32)
                        : null),
              ),
              if (avatarBadge != null)
                Positioned(right: 0, bottom: 0, child: avatarBadge!),
            ],
          ),
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
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified, size: 16, color: AppColors.accent),
                  ],
                  if (isPremium) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.premiumBadgeTooltip,
                      child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                    ),
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
        ?trailing,
      ],
    );
  }
}

/// Linia orizontală cu statistici, separată printr-o linie subțire jos, ca
/// reper vizual pentru finalul header-ului. Format comun între profilul
/// propriu și cel public.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});
  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            _stat(context, stats[i]),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, ProfileStat stat) {
    return Row(
      children: [
        if (stat.icon != null) ...[
          Icon(stat.icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 3),
        ],
        Text(stat.value, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 6),
        Text(stat.label, style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
      ],
    );
  }
}

class ProfileStat {
  const ProfileStat({required this.value, required this.label, this.icon});
  final String value;
  final String label;
  final IconData? icon;
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 4),
            ],
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
