import 'package:flutter/material.dart';

import '../../logic/levels.dart';
import '../../logic/quiz.dart';
import '../../models/deck.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/format.dart';
import '../badges_screen.dart';
import '../review_screen.dart';
import 'quiz_intro_screen.dart';

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({super.key, required this.summary, this.chapter});

  final QuizSummary summary;
  final Chapter? chapter;

  void _retake(BuildContext context) => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => QuizIntroScreen(chapter: chapter)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Tier.of(context).isJunior
        ? const Color(0xFFEDE9FE)
        : AppColors.ground,
    body: SafeArea(
      child: Tier.of(context).isJunior
          ? _Junior(summary: summary, onAgain: () => _retake(context))
          : _Senior(
              summary: summary,
              chapter: chapter,
              onRetake: () => _retake(context),
            ),
    ),
  );
}

/// Three stars, filled up to [count].
class QuizStarsRow extends StatelessWidget {
  const QuizStarsRow({super.key, required this.count, this.size = 48});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count of 3 stars',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            Icons.star_rounded,
            size: i == 1 ? size * 1.2 : size,
            color: i < count ? AppColors.star : const Color(0xFFE3D8C6),
          ),
      ],
    ),
  );
}

String _nextStarHint(QuizSummary s) {
  if (s.quizStars >= 3) return '';
  final need = scoreForStars(s.quizStars + 1, s.total);
  final which = const ['first', 'second', 'third'][s.quizStars];
  return 'Get $need out of ${s.total} for the $which star';
}

class _Mistake extends StatelessWidget {
  const _Mistake({required this.answer, required this.junior});

  final QuizAnswer answer;
  final bool junior;

  @override
  Widget build(BuildContext context) {
    final q = answer.question;
    final label = TextStyle(
      fontSize: junior ? 16 : 13,
      fontWeight: FontWeight.w800,
      color: AppColors.inkMuted,
    );
    final value = TextStyle(
      fontSize: junior ? 20 : 15,
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: junior ? 16 : 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              questionText(q),
              style: TextStyle(
                fontFamily: junior ? Fonts.display : Fonts.body,
                fontSize: junior ? 20 : 15,
                fontWeight: junior ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: junior ? 'You said ' : 'You: ',
                        style: label,
                      ),
                      TextSpan(
                        text: answer.given ?? 'skipped',
                        style: value.copyWith(color: AppColors.againInk),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Answer: ', style: label),
                      TextSpan(
                        text: correctText(q),
                        style: value.copyWith(color: AppColors.knewInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Junior extends StatelessWidget {
  const _Junior({required this.summary, required this.onAgain});

  final QuizSummary summary;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final name = AppScope.of(context).current!.name;
    final perfect = s.score == s.total;
    final heading = perfect ? 'Brilliant, $name!' : 'Great try, $name!';
    final hint = _nextStarHint(s);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const Center(child: MyOwl(size: 104)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        heading,
                        style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ReadAloudButton(
                      '$heading You got ${s.score} out of ${s.total}. $hint',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFD6CCF3), offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      QuizStarsRow(count: s.quizStars),
                      const SizedBox(height: 8),
                      Text(
                        '${s.score} out of ${s.total}',
                        style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hint.isNotEmpty)
                        Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      if (s.starsEarned > 0) ...[
                        const SizedBox(height: 12),
                        StatPill.stars(s.starsEarned),
                      ],
                    ],
                  ),
                ),
                for (final b in s.newBadges) ...[
                  const SizedBox(height: 12),
                  NewBadgeCard(badge: b),
                ],
                if (s.quiz.mistakes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Let's look again",
                          style: TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ReadAloudButton(
                        s.quiz.mistakes
                            .map(
                              (a) =>
                                  '${questionText(a.question)} The answer is ${correctText(a.question)}.',
                            )
                            .join(' '),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final a in s.quiz.mistakes)
                    _Mistake(answer: a, junior: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAgain,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Play again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Senior extends StatelessWidget {
  const _Senior({
    required this.summary,
    required this.chapter,
    required this.onRetake,
  });

  final QuizSummary summary;
  final Chapter? chapter;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = summary;
    final pct = (s.score * 100 / s.total).round();
    final subject = chapter == null
        ? null
        : state.subjectById(chapter!.subjectId);
    final title = chapter == null
        ? 'Mixed quiz'
        : '${subject!.name} · Ch ${chapter!.number} quiz';
    final best = s.previousBest;
    final bestLine = best == null
        ? 'First try'
        : s.score / s.total > best.accuracy
        ? 'New best! Was ${best.score}/${best.total}'
        : 'Best is ${best.score}/${best.total}';
    final mistakes = s.quiz.mistakes;
    final missedCards = s.quiz.missed;
    final threeStarAt = scoreForStars(3, s.total);
    final praise = pct >= 90
        ? 'Excellent'
        : pct >= 70
        ? 'Good work'
        : pct >= 50
        ? 'Nice effort'
        : 'Keep practising';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${s.score}/${s.total}',
                          style: const TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '  $pct%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(child: QuizStarsRow(count: s.quizStars, size: 32)),
                const SizedBox(height: 6),
                Text(
                  '$praise, ${state.current!.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (s.quizStars < 3)
                  Text(
                    '$threeStarAt/${s.total} or better for 3 stars',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.inkMuted,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(value: '+${s.xpEarned}', label: 'XP earned'),
                    const SizedBox(width: 10),
                    _Stat(value: clock(s.duration), label: 'Time'),
                    const SizedBox(width: 10),
                    _Stat(
                      value: best == null
                          ? '—'
                          : '${s.score - best.score >= 0 ? '+' : ''}${s.score - best.score}',
                      label: bestLine,
                    ),
                  ],
                ),
                for (final b in s.newBadges) ...[
                  const SizedBox(height: 12),
                  NewBadgeCard(badge: b),
                ],
                if (mistakes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Mistakes to review · ${mistakes.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final a in mistakes) _Mistake(answer: a, junior: false),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (missedCards.isNotEmpty) ...[
            PrimaryButton(
              label:
                  'Review ${missedCards.length} mistake${missedCards.length == 1 ? '' : 's'}',
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ReviewScreen(cards: missedCards, practice: true),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetake,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: missedCards.isEmpty
                    ? PrimaryButton(
                        label: 'Done',
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    : OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Done'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: SoftCard(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
        ],
      ),
    ),
  );
}
