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

  /// Explică de unde vine XP-ul și că nu există nivel maxim. Valorile vin din
  /// `stats.xpRewards`, adică de la backend - nu sunt scrise a doua oară aici.
  void _showXpExplainer(BuildContext context) {
    final l10n = context.l10n;
    final labels = <String, String>{
      'bookListed': l10n.gamificationXpBookListed,
      'exchangeCompleted': l10n.gamificationXpExchangeCompleted,
      'saleCompleted': l10n.gamificationXpSaleCompleted,
      'reviewWritten': l10n.gamificationXpReviewWritten,
    };
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.gamificationHowItWorks),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.gamificationXpIntro(stats.xpPerLevel)),
            const SizedBox(height: 12),
            for (final entry in stats.xpRewards.entries)
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = 1 - (stats.xpToNextLevel / stats.xpPerLevel);

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
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: l10n.gamificationHowItWorks,
                  onPressed: () => _showXpExplainer(context),
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
