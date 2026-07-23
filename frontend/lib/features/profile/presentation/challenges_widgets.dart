import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_repository.dart';

final monthlyChallengesProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getMonthlyChallenges();
});

final readingChallengeProvider = FutureProvider((ref) {
  return ref.watch(profileRepositoryProvider).getReadingChallenge();
});

/// Monthly Challenges - 3 praguri simple recalculate live din activitatea
/// lunii curente (vezi getMonthlyChallenges în backend), fără premii sau
/// un sistem separat de misiuni.
class MonthlyChallengesCard extends ConsumerWidget {
  const MonthlyChallengesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monthlyChallengesProvider);
    final l10n = context.l10n;

    return async.when(
      data: (challenges) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.monthlyChallengesTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              for (final challenge in challenges) ...[
                Row(
                  children: [
                    Icon(
                      challenge.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: challenge.completed ? const Color(0xFF2E7D32) : AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(challenge.label, style: Theme.of(context).textTheme.bodyMedium)),
                    Text(
                      '${challenge.progress}/${challenge.goal}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Reading Challenge - obiectiv anual opțional, setat de user; progresul
/// vine din cărțile marcate "Finished" pe Public Bookshelf anul curent.
class ReadingChallengeCard extends ConsumerWidget {
  const ReadingChallengeCard({super.key});

  Future<void> _setGoal(BuildContext context, WidgetRef ref, int? currentGoal) async {
    final controller = TextEditingController(text: currentGoal?.toString() ?? '');
    final l10n = context.l10n;
    final goal = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.readingChallengeSetGoal),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.readingChallengeGoalLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (goal != null && goal > 0) {
      await ref.read(profileRepositoryProvider).setReadingChallengeGoal(goal);
      ref.invalidate(readingChallengeProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(readingChallengeProvider);
    final l10n = context.l10n;

    return async.when(
      data: (challenge) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.readingChallengeTitle(challenge.year), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              if (challenge.goal == null)
                OutlinedButton(
                  onPressed: () => _setGoal(context, ref, challenge.goal),
                  child: Text(l10n.readingChallengeSetGoal),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (challenge.progress / challenge.goal!).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.readingChallengeProgress(challenge.progress, challenge.goal!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => _setGoal(context, ref, challenge.goal),
                      child: Text(l10n.readingChallengeSetGoal),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
