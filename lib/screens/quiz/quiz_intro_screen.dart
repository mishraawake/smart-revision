import 'package:flutter/material.dart';

import '../../logic/levels.dart';
import '../../logic/quiz.dart';
import '../../models/deck.dart';
import '../../models/profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'quiz_screen.dart';

/// Opens the quiz intro for [chapter], or a mixed quiz when it is null.
void openQuiz(BuildContext context, {Chapter? chapter}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => QuizIntroScreen(chapter: chapter)),
  );
}

class QuizIntroScreen extends StatefulWidget {
  const QuizIntroScreen({super.key, this.chapter});

  final Chapter? chapter;

  @override
  State<QuizIntroScreen> createState() => _QuizIntroScreenState();
}

class _QuizIntroScreenState extends State<QuizIntroScreen> {
  late int _count = AppScope.read(context).current!.isJunior ? 5 : 10;
  var _timed = false;

  void _start() {
    final state = AppScope.read(context);
    final ch = widget.chapter;
    final questions = ch == null
        ? state.mixedQuiz(count: _count)
        : state.chapterQuiz(ch, count: _count);
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough cards here for a quiz yet.')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            QuizScreen(questions: questions, chapter: ch, timed: _timed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ch = widget.chapter;
    final subject = ch == null ? null : state.subjectById(ch.subjectId);
    final context_ = ch == null
        ? 'All subjects'
        : '${subject!.name} · Chapter ${ch.number}';
    final title = ch?.title ?? 'Mixed quiz';
    return Tier.of(context).isJunior
        ? _JuniorIntro(
            context: context_,
            title: title,
            count: _count,
            onStart: _start,
            subjectId: ch?.subjectId,
          )
        : _SeniorIntro(
            heading: ch == null ? 'Mixed quiz' : 'Chapter quiz',
            context: context_,
            title: title,
            count: _count,
            onCount: (n) => setState(() => _count = n),
            timed: _timed,
            onTimed: (v) => setState(() => _timed = v),
            best: ch == null ? null : state.bestQuiz(ch.id),
            onStart: _start,
          );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Go back',
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox.square(
          dimension: size,
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    ),
  );
}

class _JuniorIntro extends StatelessWidget {
  const _JuniorIntro({
    required this.context,
    required this.title,
    required this.count,
    required this.onStart,
    required this.subjectId,
  });

  final String context;
  final String title;
  final int count;
  final VoidCallback onStart;
  final String? subjectId;

  @override
  Widget build(BuildContext buildContext) {
    final style = SubjectStyle.of(subjectId ?? '');
    return Scaffold(
      backgroundColor: const Color(0xFFEDE9FE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _BackButton(),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      context,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: subjectId == null
                            ? AppColors.primary
                            : style.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    const Center(child: Owl(size: 132)),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Quiz time!',
                        style: TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3B1D8F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFD6CCF3),
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: Fonts.display,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              ReadAloudButton(
                                '$title. $count questions. '
                                'Win up to 3 stars. No timer, take your time!',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _IntroTile(
                                  background: AppColors.primaryTint,
                                  value: '$count',
                                  label: 'questions',
                                  labelColor: AppColors.onPrimaryTint,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: _IntroTile(
                                  background: AppColors.starBg,
                                  value: '3',
                                  label: 'stars to win',
                                  labelColor: AppColors.starInk,
                                  stars: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No timer. Take your time!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3D3654),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Start quiz',
                icon: Icons.play_arrow_rounded,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroTile extends StatelessWidget {
  const _IntroTile({
    required this.background,
    required this.value,
    required this.label,
    required this.labelColor,
    this.stars = false,
  });

  final Color background;
  final String value;
  final String label;
  final Color labelColor;
  final bool stars;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stars)
          const Row(
            children: [
              StarIcon(size: 18),
              StarIcon(size: 18),
              StarIcon(size: 18),
            ],
          )
        else
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SeniorIntro extends StatelessWidget {
  const _SeniorIntro({
    required this.heading,
    required this.context,
    required this.title,
    required this.count,
    required this.onCount,
    required this.timed,
    required this.onTimed,
    required this.best,
    required this.onStart,
  });

  final String heading;
  final String context;
  final String title;
  final int count;
  final ValueChanged<int> onCount;
  final bool timed;
  final ValueChanged<bool> onTimed;
  final QuizRecord? best;
  final VoidCallback onStart;

  static const _types = [
    'Multiple choice',
    'True / false',
    'Fill the blank',
    'Match pairs',
  ];

  @override
  Widget build(BuildContext buildContext) {
    final minutes = (count * 0.8).round();
    final maxXp = count * Xp.perRightAnswer + Xp.threeStarBonus;
    const label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.inkMuted,
    );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _BackButton(size: 44),
                  const SizedBox(width: 12),
                  Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    Text(context, style: label),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Mixed questions from the cards you've studied. "
                      'Mistakes go to your review deck.',
                      style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 20),
                    const Text('Questions', style: label),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5')),
                        ButtonSegment(value: 8, label: Text('8')),
                        ButtonSegment(value: 10, label: Text('10')),
                      ],
                      selected: {count},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => onCount(s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'About $minutes min · Up to $maxXp XP',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("What's inside", style: label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in _types)
                          Chip(
                            label: Text(t),
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: AppColors.groundBorder,
                            ),
                          ),
                      ],
                    ),
                    if (best != null) ...[
                      const SizedBox(height: 20),
                      SoftCard(
                        padding: 14,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.starStroke,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Your best',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                            Text(
                              '${best!.score}/${best!.total}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SoftCard(
                      padding: 4,
                      child: SwitchListTile(
                        value: timed,
                        onChanged: onTimed,
                        title: const Text(
                          'Timed mode',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('60 s per question'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Start quiz', onPressed: onStart),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain-text form of a question, for mistakes lists and read-aloud.
String questionText(QuizQuestion q) => switch (q) {
  McqQuestion(:final card) => card.front,
  TrueFalseQuestion(:final statement, :final claim) =>
    claim == null ? statement : '$statement Answer: $claim',
  FillBlankQuestion(:final sentence, :final card) =>
    sentence?.replaceAll('___', '____') ?? card.front,
  MatchQuestion() => 'Match the pairs',
};

/// The right answer, as words.
String correctText(QuizQuestion q) => switch (q) {
  McqQuestion(:final correct) => correct,
  TrueFalseQuestion(:final isTrue) => isTrue ? 'True' : 'False',
  FillBlankQuestion(:final answer) => answer,
  MatchQuestion(:final pairs) =>
    pairs.map((p) => '${p.left} → ${p.right}').join(', '),
};
