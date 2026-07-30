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
  'top_swapper': Icons.emoji_events,
  'supporter': Icons.local_cafe,
};

/// Insignele într-un `ExpansionTile`, colapsat implicit.
///
/// Grila completă are 14 insigne și ocupa jumătate de ecran chiar și când
/// aproape niciuna nu era obținută. Colapsat, rândul arată doar câte au fost
/// obținute din total; cine vrea lista o deschide.
class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key, required this.achievements, required this.title});
  final List<Achievement> achievements;
  final String title;

  @override
  Widget build(BuildContext context) {
    final earned = achievements.where((a) => a.achieved).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(Icons.workspace_premium_outlined, color: AppColors.accent),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          '$earned / ${achievements.length}',
          style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AchievementsGrid(achievements: achievements),
          ),
        ],
      ),
    );
  }
}

class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({super.key, required this.achievements});
  final List<Achievement> achievements;

  /// Detaliile insignei la tap. Înainte erau doar într-un `Tooltip`, adică
  /// invizibile pe telefon - pe touch nu există hover.
  void _showDetails(BuildContext context, Achievement achievement) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          _badgeIcons[achievement.key] ?? Icons.emoji_events_outlined,
          color: achievement.achieved ? AppColors.accent : AppColors.mutedForeground,
          size: 36,
        ),
        title: Text(achievement.label, textAlign: TextAlign.center),
        content: Text(achievement.description, textAlign: TextAlign.center),
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final achievement in achievements)
          InkWell(
            onTap: () => _showDetails(context, achievement),
            borderRadius: BorderRadius.circular(12),
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
