import 'package:flutter/material.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';
import '../../l10n/app_localizations.dart';

/// Afișează scorul de încredere (0-100). Inline (pe profilul public) e colapsat
/// implicit și tap oriunde pe card extinde detaliile. Deschis dintr-un dialog -
/// adică atunci când userul a apăsat deja pe scor - se construiește cu
/// [initiallyExpanded] și [collapsible] `false`: detaliile apar direct, fără să
/// mai fie nevoie de un al doilea tap.
/// E doar un indicator calculat din activitatea din aplicație, nu o
/// certificare de identitate.
class TrustScoreCard extends StatefulWidget {
  const TrustScoreCard({
    super.key,
    required this.trustScore,
    this.initiallyExpanded = false,
    this.collapsible = true,
  });
  final TrustScore trustScore;
  final bool initiallyExpanded;
  final bool collapsible;

  @override
  State<TrustScoreCard> createState() => _TrustScoreCardState();
}

class _TrustScoreCardState extends State<TrustScoreCard> {
  late bool _expanded = widget.initiallyExpanded;

  Color _scoreColor() {
    if (widget.trustScore.score >= 70) return const Color(0xFF2E7D32);
    if (widget.trustScore.score >= 40) return AppColors.accent;
    return AppColors.destructive;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor();
    final l10n = context.l10n;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.collapsible
            ? () => setState(() => _expanded = !_expanded)
            : null,
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
                      '${widget.trustScore.score}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trustScoreTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          l10n.trustScoreSubtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Chevron care se rotește la extindere - semnalul vizual că
                  // e clickable, altfel cardul arată ca un simplu display.
                  // Când cardul nu e colapsabil nu are ce semnala.
                  if (widget.collapsible)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
              // AnimatedSize + AnimatedCrossFade: schimbă între „vid" și
              // detalii cu tranziție lină. Wrap-ul cu chip-urile e greu de
              // recalculat, deci îl construim mereu și îl ascundem doar
              // vizual când e colapsat.
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildDetails(l10n),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(AppLocalizations l10n) {
    final t = widget.trustScore;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (t.isEmailVerified)
          Chip(
            avatar: const Icon(Icons.mark_email_read_outlined, size: 16),
            label: Text(l10n.trustScoreEmailVerified),
            visualDensity: VisualDensity.compact,
          ),
        Chip(
          avatar: const Icon(Icons.cake_outlined, size: 16),
          label: Text(_accountAgeLabel(l10n, t.accountAgeDays)),
          visualDensity: VisualDensity.compact,
        ),
        if (t.completedExchangeRate != null)
          Chip(
            avatar: const Icon(Icons.check_circle_outline, size: 16),
            label: Text(
              l10n.trustScoreCompletedRate(
                (t.completedExchangeRate! * 100).round(),
              ),
            ),
            visualDensity: VisualDensity.compact,
          ),
        if (t.averageResponseHours != null)
          Chip(
            avatar: const Icon(Icons.schedule_outlined, size: 16),
            label: Text(
              l10n.trustScoreRespondsIn(_formatHours(l10n, t.averageResponseHours!)),
            ),
            visualDensity: VisualDensity.compact,
          ),
        if (t.lastActiveAt != null)
          Chip(
            avatar: const Icon(Icons.circle, size: 10, color: Color(0xFF2E7D32)),
            label: Text(_lastActiveLabel(l10n, t.lastActiveAt!)),
            visualDensity: VisualDensity.compact,
          ),
        if (t.responseRate != null)
          Chip(
            avatar: const Icon(Icons.forum_outlined, size: 16),
            label: Text(l10n.trustScoreResponseRate((t.responseRate! * 100).round())),
            visualDensity: VisualDensity.compact,
          ),
        if (t.averageSwapTimeHours != null)
          Chip(
            avatar: const Icon(Icons.swap_horiz, size: 16),
            label: Text(
              l10n.trustScoreAverageSwapTime(_formatHours(l10n, t.averageSwapTimeHours!)),
            ),
            visualDensity: VisualDensity.compact,
          ),
        if (t.avgCommunicationRating != null)
          Chip(
            avatar: const Icon(Icons.chat_outlined, size: 16),
            label: Text('${l10n.exchangeRatingCommunication}: ${t.avgCommunicationRating}'),
            visualDensity: VisualDensity.compact,
          ),
        if (t.avgPunctualityRating != null)
          Chip(
            avatar: const Icon(Icons.access_time, size: 16),
            label: Text('${l10n.exchangeRatingPunctuality}: ${t.avgPunctualityRating}'),
            visualDensity: VisualDensity.compact,
          ),
        if (t.avgConditionRating != null)
          Chip(
            avatar: const Icon(Icons.auto_stories_outlined, size: 16),
            label: Text('${l10n.exchangeRatingCondition}: ${t.avgConditionRating}'),
            visualDensity: VisualDensity.compact,
          ),
      ],
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
