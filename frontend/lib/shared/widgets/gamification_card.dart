import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';

/// XP & Levels + Reading Streak - vezi GamificationStats în
/// data/models/user.dart pentru sursa numerelor (nivel calculat din xp
/// total, nu stocat separat).
class GamificationCard extends StatelessWidget {
  const GamificationCard({super.key, required this.stats});
  final GamificationStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = 1 - (stats.xpToNextLevel / 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  child: Text(
                    '${stats.level}',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.gamificationLevel(stats.level), style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        l10n.gamificationXpToNextLevel(stats.xpToNextLevel),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 6,
                backgroundColor: AppColors.muted,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            if (stats.currentStreakDays > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.local_fire_department_outlined, size: 16),
                    label: Text(l10n.gamificationStreak(stats.currentStreakDays)),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (stats.longestStreakDays > stats.currentStreakDays)
                    Chip(
                      avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                      label: Text(l10n.gamificationLongestStreak(stats.longestStreakDays)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
