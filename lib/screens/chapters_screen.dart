import 'package:flutter/material.dart';

import '../models/deck.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../models/profile.dart';
import 'quiz/quiz_intro_screen.dart';
import 'review_screen.dart';

String _quizLabel(QuizRecord? best) =>
    best == null ? 'Quiz' : 'Quiz · best ${best.score}/${best.total}';

class ChaptersScreen extends StatelessWidget {
  const ChaptersScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final subject = state.subjectById(subjectId)!;
    final style = SubjectStyle.of(subjectId);
    final junior = Tier.of(context).isJunior;
    final pct = (state.learntFraction(subject.cards) * 100).round();
    final last = state.lastChapter;
    final resume = last != null && last.subjectId == subjectId ? last : null;
    final resumeDue = resume == null ? 0 : state.chapterDue(resume);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: style.background,
        foregroundColor: style.foreground,
        toolbarHeight: junior ? 96 : 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.name,
              style: TextStyle(
                fontFamily: Fonts.display,
                fontSize: junior ? 30 : 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              junior
                  ? '${subject.chapters.length} chapters · $pct% learnt'
                  : 'Class ${state.current!.classLevel} · ${subject.chapters.length} chapters · $pct% mastered',
              style: TextStyle(
                fontSize: junior ? 16 : 13,
                fontWeight: FontWeight.w700,
                color: style.foreground,
              ),
            ),
          ],
        ),
        actions: [
          if (junior)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ReadAloudButton('${subject.name}. Pick a chapter.'),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: subject.chapters.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _ChapterRow(
          state: state,
          chapter: subject.chapters[i],
          junior: junior,
        ),
      ),
      bottomNavigationBar: !junior && resume != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: PrimaryButton(
                  label: resumeDue > 0
                      ? 'Continue Ch ${resume.number} · $resumeDue due'
                      : 'Continue Ch ${resume.number}',
                  onPressed: () => _open(context, state, resume),
                ),
              ),
            )
          : null,
    );
  }
}

void _open(BuildContext context, AppState state, Chapter ch) {
  final queue = state.chapterQueue(ch);
  if (queue.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Tier.of(context).isJunior
              ? 'All learnt! Come back tomorrow.'
              : 'Nothing due in this chapter. Practising learnt cards.',
        ),
      ),
    );
    if (!Tier.of(context).isJunior) {
      startReview(
        context,
        ch.cards.take(state.sessionSize).toList(),
        practice: true,
      );
    }
    return;
  }
  startReview(context, queue);
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.state,
    required this.chapter,
    required this.junior,
  });
  final AppState state;
  final Chapter chapter;
  final bool junior;

  @override
  Widget build(BuildContext context) {
    final frac = state.learntFraction(chapter.cards);
    final pct = (frac * 100).round();
    final started = state.isStarted(chapter);
    final status = [
      if (!started)
        'Not started · ${chapter.cards.length} cards'
      else if (frac == 1)
        '${state.levelOf(chapter).label} · all learnt'
      else
        '${state.levelOf(chapter).label} · $pct% learnt',
      if (!state.isCovered(chapter)) 'not done at school yet',
    ].join(' · ');

    return SoftCard(
      padding: junior ? 16 : 14,
      onTap: () => _open(context, state, chapter),
      child: Row(
        children: [
          Container(
            width: junior ? 52 : 40,
            height: junior ? 52 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: frac == 1 ? AppColors.knew : AppColors.chip,
            ),
            child: frac == 1
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : Text(
                    junior
                        ? '${chapter.number}'
                        : chapter.number.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: junior ? 24 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.title,
                  style: junior
                      ? const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        )
                      : const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                ),
                const SizedBox(height: 6),
                if (started) ...[
                  ProgressBar(
                    frac,
                    color: frac == 1 ? AppColors.knew : AppColors.primary,
                    height: junior ? 10 : 6,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  status,
                  style: TextStyle(
                    fontSize: junior ? 16 : 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => openQuiz(context, chapter: chapter),
                  icon: const Icon(Icons.quiz_rounded),
                  label: Text(_quizLabel(state.bestQuiz(chapter.id))),
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, junior ? 48 : 40),
                    backgroundColor: AppColors.primaryTint,
                    foregroundColor: AppColors.onPrimaryTint,
                    textStyle: TextStyle(
                      fontSize: junior ? 17 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (junior) ...[
            const SizedBox(width: 8),
            ReadAloudButton(chapter.title, size: 48),
          ],
        ],
      ),
    );
  }
}
