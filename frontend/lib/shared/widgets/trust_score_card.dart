import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';

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
                      Text('Scor de încredere', style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        'Calculat din activitatea din aplicație, nu e o verificare de identitate',
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
                  const Chip(
                    avatar: Icon(Icons.mark_email_read_outlined, size: 16),
                    label: Text('Email verificat'),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  avatar: const Icon(Icons.cake_outlined, size: 16),
                  label: Text(_accountAgeLabel(trustScore.accountAgeDays)),
                  visualDensity: VisualDensity.compact,
                ),
                if (trustScore.completedExchangeRate != null)
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      '${(trustScore.completedExchangeRate! * 100).round()}% schimburi finalizate',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (trustScore.averageResponseHours != null)
                  Chip(
                    avatar: const Icon(Icons.schedule_outlined, size: 16),
                    label: Text('Răspunde în ~${_formatHours(trustScore.averageResponseHours!)}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _accountAgeLabel(int days) {
    if (days < 30) return 'Membru din $days zile';
    if (days < 365) return 'Membru de ${(days / 30).floor()} luni';
    return 'Membru de ${(days / 365).floor()} ani';
  }

  String _formatHours(double hours) {
    if (hours < 1) return '${(hours * 60).round()} min';
    if (hours < 24) return '${hours.round()}h';
    return '${(hours / 24).round()} zile';
  }
}
