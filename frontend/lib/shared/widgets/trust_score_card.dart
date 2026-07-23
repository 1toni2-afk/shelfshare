import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';
import '../../l10n/app_localizations.dart';

/// Afișează scorul de încredere (0-100) și detaliile din spatele lui.
/// E doar un indicator calculat din activitatea din aplicație, nu o
/// certificare de identitate - textul din widget lasă asta clar.
class TrustScoreCard extends StatelessWidget {
  const TrustScoreCard({super.key, required this.trustScore});
  final TrustScore trustScore;

  Color _scoreColor() {
    if (trustScore.score >= 70) return const Color(0xFF2E7D32);
    if (trustScore.score >= 40) return AppColors.accent;
    return AppColors.destructive;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor();
    final l10n = context.l10n;

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
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    '${trustScore.score}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.trustScoreTitle, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        l10n.trustScoreSubtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (trustScore.isEmailVerified)
                  Chip(
                    avatar: const Icon(Icons.mark_email_read_outlined, size: 16),
                    label: Text(l10n.trustScoreEmailVerified),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  avatar: const Icon(Icons.cake_outlined, size: 16),
                  label: Text(_accountAgeLabel(l10n, trustScore.accountAgeDays)),
                  visualDensity: VisualDensity.compact,
                ),
                if (trustScore.completedExchangeRate != null)
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      l10n.trustScoreCompletedRate(
                        (trustScore.completedExchangeRate! * 100).round(),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.averageResponseHours != null)
                  Chip(
                    avatar: const Icon(Icons.schedule_outlined, size: 16),
                    label: Text(
                      l10n.trustScoreRespondsIn(_formatHours(l10n, trustScore.averageResponseHours!)),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.lastActiveAt != null)
                  Chip(
                    avatar: const Icon(Icons.circle, size: 10, color: Color(0xFF2E7D32)),
                    label: Text(_lastActiveLabel(l10n, trustScore.lastActiveAt!)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.responseRate != null)
                  Chip(
                    avatar: const Icon(Icons.forum_outlined, size: 16),
                    label: Text(l10n.trustScoreResponseRate((trustScore.responseRate! * 100).round())),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.averageSwapTimeHours != null)
                  Chip(
                    avatar: const Icon(Icons.swap_horiz, size: 16),
                    label: Text(
                      l10n.trustScoreAverageSwapTime(_formatHours(l10n, trustScore.averageSwapTimeHours!)),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.avgCommunicationRating != null)
                  Chip(
                    avatar: const Icon(Icons.chat_outlined, size: 16),
                    label: Text('${l10n.exchangeRatingCommunication}: ${trustScore.avgCommunicationRating}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.avgPunctualityRating != null)
                  Chip(
                    avatar: const Icon(Icons.access_time, size: 16),
                    label: Text('${l10n.exchangeRatingPunctuality}: ${trustScore.avgPunctualityRating}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.avgConditionRating != null)
                  Chip(
                    avatar: const Icon(Icons.auto_stories_outlined, size: 16),
                    label: Text('${l10n.exchangeRatingCondition}: ${trustScore.avgConditionRating}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _accountAgeLabel(AppLocalizations l10n, int days) {
    if (days < 30) return l10n.memberSinceDays(days);
    if (days < 365) return l10n.memberSinceMonths((days / 30).floor());
    return l10n.memberSinceYears((days / 365).floor());
  }

  String _lastActiveLabel(AppLocalizations l10n, DateTime lastActiveAt) {
    final days = DateTime.now().difference(lastActiveAt).inDays;
    if (days <= 0) return l10n.trustScoreLastActiveToday;
    return l10n.trustScoreLastActiveDays(days);
  }

  String _formatHours(AppLocalizations l10n, double hours) {
    if (hours < 1) return l10n.durationMinutes((hours * 60).round());
    if (hours < 24) return l10n.durationHours(hours.round());
    return l10n.durationDays((hours / 24).round());
  }
}
