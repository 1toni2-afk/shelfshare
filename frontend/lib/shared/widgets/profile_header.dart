import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';

/// Antetul comun oricărui ecran de profil (al meu sau public): avatar,
/// nume, câteva linii de subtitlu (oraș, email, membru din...), statistici
/// și, opțional, descrierea. Randat de my_profile_screen.dart și
/// public_profile_screen.dart, ca să nu diveargă vizual în timp.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profileImage,
    required this.name,
    this.username,
    required this.subtitleLines,
    required this.rating,
    required this.booksExchangedCount,
    this.bio,
    this.bioTitle,
  });

  final String? profileImage;
  final String? name;
  final String? username;
  final List<String> subtitleLines;
  final double rating;
  final int booksExchangedCount;
  final String? bio;
  final String? bioTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final usernameLabel = username != null ? '@$username' : null;
    return Column(
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundImage: profileImage != null ? NetworkImage(profileImage!) : null,
            child: profileImage == null ? const Icon(Icons.person, size: 48) : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name ?? usernameLabel ?? l10n.commonUnknownUser,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (name != null && usernameLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            usernameLabel,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
        for (final line in subtitleLines) ...[
          const SizedBox(height: 4),
          Text(
            line,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatTile(icon: Icons.star, value: rating.toStringAsFixed(1), label: l10n.commonRating),
            StatTile(value: '$booksExchangedCount', label: l10n.commonBooksExchanged),
          ],
        ),
        if (bio != null && bio!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(bioTitle ?? l10n.commonAbout, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(bio!),
        ],
      ],
    );
  }
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
