import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';

const _badgeIcons = {
  'first_swap': Icons.emoji_events_outlined,
  'ten_swaps': Icons.workspace_premium_outlined,
  'fifty_swaps': Icons.military_tech_outlined,
  'collector': Icons.auto_stories_outlined,
  'trusted_member': Icons.verified_outlined,
  'early_adopter': Icons.rocket_launch_outlined,
  'genre_master': Icons.category_outlined,
  'community_helper': Icons.volunteer_activism_outlined,
  'explorer': Icons.explore_outlined,
  'fantasy_collector': Icons.auto_awesome_outlined,
  'book_explorer': Icons.travel_explore_outlined,
};

class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({super.key, required this.achievements});
  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final achievement in achievements)
          Tooltip(
            message: achievement.description,
            child: Opacity(
              opacity: achievement.achieved ? 1 : 0.35,
              child: Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: achievement.achieved ? AppColors.accent.withValues(alpha: 0.12) : AppColors.muted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: achievement.achieved ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _badgeIcons[achievement.key] ?? Icons.emoji_events_outlined,
                      color: achievement.achieved ? AppColors.accent : AppColors.mutedForeground,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      achievement.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
