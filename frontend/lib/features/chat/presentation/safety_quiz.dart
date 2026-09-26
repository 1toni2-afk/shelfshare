import 'package:flutter/material.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// O întrebare din testul de siguranță: trei variante, una singură corectă,
/// plus explicația arătată imediat după răspuns.
class _QuizQuestion {
  const _QuizQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

/// Întrebările se construiesc din `l10n` la fiecare build, nu o dată la
/// pornire: limba se poate schimba din Setări fără restart, iar o listă
/// statică ar rămâne în limba de la primul build.
///
/// Răspunsul corect NU e mereu pe aceeași poziție - altfel testul s-ar rezolva
/// din reflex, nu din citit.
List<_QuizQuestion> _questions(AppLocalizations l10n) => [
      _QuizQuestion(
        text: l10n.chatQuizQ1,
        options: [l10n.chatQuizQ1A, l10n.chatQuizQ1B, l10n.chatQuizQ1C],
        correctIndex: 1,
        explanation: l10n.chatQuizQ1Explain,
      ),
      _QuizQuestion(
        text: l10n.chatQuizQ2,
        options: [l10n.chatQuizQ2A, l10n.chatQuizQ2B, l10n.chatQuizQ2C],
        correctIndex: 2,
        explanation: l10n.chatQuizQ2Explain,
      ),
      _QuizQuestion(
        text: l10n.chatQuizQ3,
        options: [l10n.chatQuizQ3A, l10n.chatQuizQ3B, l10n.chatQuizQ3C],
        correctIndex: 0,
        explanation: l10n.chatQuizQ3Explain,
      ),
      _QuizQuestion(
        text: l10n.chatQuizQ4,
        options: [l10n.chatQuizQ4A, l10n.chatQuizQ4B, l10n.chatQuizQ4C],
        correctIndex: 1,
        explanation: l10n.chatQuizQ4Explain,
      ),
      _QuizQuestion(
        text: l10n.chatQuizQ5,
        options: [l10n.chatQuizQ5A, l10n.chatQuizQ5B, l10n.chatQuizQ5C],
        correctIndex: 2,
        explanation: l10n.chatQuizQ5Explain,
      ),
    ];

/// Testul de siguranță din panoul de chat, arătat cât timp nu e deschisă nicio
/// conversație. Sfaturile scrise le citește puțină lume; aceleași reguli sub
/// formă de întrebare se rețin pentru că întâi alegi, apoi vezi de ce.
///
/// Totul e local (fără rețea, fără scor salvat): scopul e să se citească
/// explicațiile, nu să se țină o statistică.
class SafetyQuiz extends StatefulWidget {
  const SafetyQuiz({super.key});

  @override
  State<SafetyQuiz> createState() => _SafetyQuizState();
}

class _SafetyQuizState extends State<SafetyQuiz> {
  bool _started = false;
  int _index = 0;
  int? _selected;
  int _score = 0;
  bool _finished = false;

  void _answer(int option, int correctIndex) {
    if (_selected != null) return; // un singur răspuns per întrebare
    setState(() {
      _selected = option;
      if (option == correctIndex) _score++;
    });
  }

  void _next(int total) {
    setState(() {
      if (_index + 1 >= total) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
      }
    });
  }

  void _restart() {
    setState(() {
      _started = true;
      _index = 0;
      _selected = null;
      _score = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final questions = _questions(l10n);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.chatQuizTitle,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_started)
            ..._intro(l10n)
          else if (_finished)
            ..._result(l10n, questions.length)
          else
            ..._question(l10n, questions[_index], questions.length),
        ],
      ),
    );
  }

  List<Widget> _intro(AppLocalizations l10n) => [
        Text(
          l10n.chatQuizIntro,
          style: TextStyle(
              color: AppColors.mutedForeground, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => setState(() => _started = true),
            child: Text(l10n.chatQuizStart),
          ),
        ),
      ];

  List<Widget> _question(
    AppLocalizations l10n,
    _QuizQuestion question,
    int total,
  ) {
    final answered = _selected != null;
    final isCorrect = _selected == question.correctIndex;
    return [
      Text(
        l10n.chatQuizProgress(_index + 1, total),
        style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
      ),
      const SizedBox(height: 8),
      Text(
        question.text,
        style: TextStyle(
          color: AppColors.foreground,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < question.options.length; i++)
        _OptionTile(
          label: question.options[i],
          // Înainte de răspuns nicio variantă nu e marcată; după, se colorează
          // și cea corectă, chiar dacă userul a ales altceva - altfel ar rămâne
          // cu greșeala pe ecran fără să vadă care era varianta bună.
          state: !answered
              ? _OptionState.idle
              : i == question.correctIndex
                  ? _OptionState.correct
                  : i == _selected
                      ? _OptionState.wrong
                      : _OptionState.idle,
          onTap: answered ? null : () => _answer(i, question.correctIndex),
        ),
      if (answered) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle_outline : Icons.info_outline,
              size: 18,
              color: isCorrect ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              isCorrect ? l10n.chatQuizCorrect : l10n.chatQuizWrong,
              style: TextStyle(
                color: isCorrect ? AppColors.success : AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          question.explanation,
          style: TextStyle(
              color: AppColors.mutedForeground, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => _next(total),
            child: Text(
              _index + 1 >= total ? l10n.chatQuizSeeResult : l10n.chatQuizNext,
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _result(AppLocalizations l10n, int total) {
    final message = _score == total
        ? l10n.chatQuizResultPerfect
        : _score * 5 >= total * 3
            ? l10n.chatQuizResultGood
            : l10n.chatQuizResultPoor;
    return [
      Text(
        l10n.chatQuizScore(_score, total),
        style: TextStyle(
          color: AppColors.foreground,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        message,
        style: TextStyle(
            color: AppColors.mutedForeground, fontSize: 13, height: 1.45),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.chatQuizRestart),
          onPressed: _restart,
        ),
      ),
    ];
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptionState.correct => AppColors.success,
      _OptionState.wrong => AppColors.destructive,
      _OptionState.idle => AppColors.border,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color,
              width: state == _OptionState.idle ? 1 : 1.5,
            ),
            color: state == _OptionState.idle
                ? AppColors.background
                : color.withValues(alpha: 0.08),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                switch (state) {
                  _OptionState.correct => Icons.check_circle,
                  _OptionState.wrong => Icons.cancel,
                  _OptionState.idle => Icons.radio_button_unchecked,
                },
                size: 18,
                color:
                    state == _OptionState.idle ? AppColors.mutedForeground : color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      color: AppColors.foreground, fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
