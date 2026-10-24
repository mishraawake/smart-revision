import 'package:flutter/material.dart';

import '../models/deck.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'chapters_screen.dart';
import 'quiz/quiz_intro_screen.dart';
import 'review_screen.dart';
import '../widgets/format.dart';
import '../widgets/study_extras.dart';
import '../widgets/teacher_work.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onOpenSubjects});

  final VoidCallback onOpenSubjects;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.deck == null) {
      return NoContentView(classLevel: state.current!.classLevel);
    }
    return Tier.of(context).isJunior
        ? _JuniorToday(state: state)
        : _SeniorToday(state: state, onOpenSubjects: onOpenSubjects);
  }
}

class _JuniorToday extends StatelessWidget {
  const _JuniorToday({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.current!;
    final queue = state.todayQueue();
    final waiting = state.todayCards().length;
    final done = state.goalDoneToday;
    final left = (p.dailyGoal - done).clamp(0, p.dailyGoal);
    final streak = state.streakOf(p);
    final last = state.lastChapter;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Row(
          children: [
            Tooltip(
              message: 'Switch student',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: state.profiles.length > 1 ? state.signOut : null,
                child: Avatar(name: p.name, index: p.avatar),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hi ${p.name}!',
                style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            ReadAloudButton(
              queue.isEmpty
                  ? 'Hi ${p.name}! All done for today!'
                  : 'Hi ${p.name}! You have $waiting cards waiting.',
            ),
          ],
        ),
        const TeacherWork(),
        const StudyExtras(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _BigStat(
                icon: const FlameIcon(size: 32),
                value: '$streak ${streak == 1 ? 'day' : 'days'}',
                label: 'streak',
                background: AppColors.streakBg,
                foreground: AppColors.streakInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStat(
                icon: const StarIcon(size: 32),
                value: formatCount(p.stars),
                label: 'stars',
                background: AppColors.starBg,
                foreground: AppColors.starInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SoftCard(
          padding: 18,
          child: Row(
            children: [
              GoalRing(
                done: done,
                goal: p.dailyGoal,
                size: 104,
                label: Text(
                  '$done/${p.dailyGoal}',
                  style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's goal",
                      style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      left == 0
                          ? 'Your ring is full!'
                          : '$left more ${left == 1 ? 'card' : 'cards'} to fill your ring',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (queue.isEmpty)
          _AllDone(streak: streak, onPractise: () => openQuiz(context))
        else
          _JuniorStartButton(
            waiting: waiting,
            onTap: () => startReview(context, queue),
          ),
        if (last != null) ...[
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Keep going',
                  style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ReadAloudButton('Keep going'),
            ],
          ),
          const SizedBox(height: 8),
          _ChapterCard(state: state, chapter: last),
        ],
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final Widget icon;
  final String value;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: foreground,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _JuniorStartButton extends StatelessWidget {
  const _JuniorStartButton({required this.waiting, required this.onTap});
  final int waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(color: AppColors.primaryDark, offset: Offset(0, 7)),
      ],
    ),
    child: Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 20),
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Start today's review",
                        style: TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$waiting ${waiting == 1 ? 'card' : 'cards'} waiting',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryTint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Junior empty state: everything due is done.
class _AllDone extends StatelessWidget {
  const _AllDone({required this.streak, required this.onPractise});
  final int streak;
  final VoidCallback onPractise;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: 20,
    child: Column(
      children: [
        const MyOwl(size: 96, sleeping: true),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(
              child: Text(
                'All done for today!',
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ReadAloudButton(
              'All done for today! Ullu is resting. New cards come tomorrow.',
            ),
          ],
        ),
        const Text(
          'Ullu is resting. New cards come tomorrow.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(height: 12),
          StatPill.streak(streak),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onPractise,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            textStyle: const TextStyle(
              fontFamily: Fonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Play a quiz for fun'),
        ),
      ],
    ),
  );
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.state, required this.chapter});
  final AppState state;
  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final subject = state.subjectById(chapter.subjectId)!;
    final style = SubjectStyle.of(subject.id);
    final pct = state.learntFraction(chapter.cards);
    return SoftCard(
      padding: 14,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChaptersScreen(subjectId: subject.id),
        ),
      ),
      child: Row(
        children: [
          SubjectBadge(subject.id, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: style.foreground,
                  ),
                ),
                Text(
                  chapter.title,
                  style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                ProgressBar(pct, color: style.foreground, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeniorToday extends StatelessWidget {
  const _SeniorToday({required this.state, required this.onOpenSubjects});
  final AppState state;
  final VoidCallback onOpenSubjects;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _greeting(DateTime t) => t.hour < 12
      ? 'Good morning'
      : t.hour < 17
      ? 'Good afternoon'
      : 'Good evening';

  @override
  Widget build(BuildContext context) {
    final p = state.current!;
    final t = state.now();
    final queue = state.todayQueue();
    final waiting = state.todayCards().length;
    final bySubject = state.dueBySubject();
    final done = state.goalDoneToday;
    final minutesLeft = ((p.dailyGoal - done).clamp(0, p.dailyGoal) * 0.5)
        .ceil();
    final week = state.weekStudied();
    final todayIndex = t.weekday % 7;
    final last = state.lastChapter;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_days[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]} · Class ${p.classLevel}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  Text(
                    '${_greeting(t)}, ${p.name}',
                    style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SwitchStudentButton(),
          ],
        ),
        const TeacherWork(),
        const StudyExtras(),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatPill.streak(state.streakOf(p)),
            StatPill.stars(p.stars),
          ],
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Row(
            children: [
              GoalRing(
                done: done,
                goal: p.dailyGoal,
                size: 64,
                stroke: 8,
                label: Text(
                  '${(done * 100 / p.dailyGoal).round().clamp(0, 100)}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      done >= p.dailyGoal
                          ? 'Goal reached · $done cards today'
                          : '$done of ${p.dailyGoal} cards · about $minutesLeft min left',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (queue.isEmpty)
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nothing due right now',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'New cards come tomorrow. You can open a chapter to study ahead.',
                  style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onOpenSubjects,
                  child: const Text('Browse subjects'),
                ),
              ],
            ),
          )
        else ...[
          PrimaryButton(
            label: "Start today's review · $waiting due",
            icon: Icons.play_arrow_rounded,
            onPressed: () => startReview(context, queue),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in bySubject.entries)
                _DueChip(
                  subjectId: e.key,
                  name: state.subjectById(e.key)!.name,
                  count: e.value,
                ),
            ],
          ),
        ],
        if (last != null) ...[
          const SizedBox(height: 20),
          const Text(
            'Continue chapter',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          SoftCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChaptersScreen(subjectId: last.subjectId),
              ),
            ),
            child: Row(
              children: [
                SubjectBadge(last.subjectId, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.subjectById(last.subjectId)!.name} · Ch ${last.number}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      Text(
                        last.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ProgressBar(state.learntFraction(last.cards)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(state.learntFraction(last.cards) * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'This week',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
            Text(
              '${week.where((d) => d).length} of 7 days',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              _WeekDot(
                letter: 'SMTWTFS'[i],
                studied: week[i],
                today: i == todayIndex,
              ),
          ],
        ),
      ],
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({
    required this.subjectId,
    required this.name,
    required this.count,
  });
  final String subjectId;
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subjectId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$name $count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: style.foreground,
        ),
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({
    required this.letter,
    required this.studied,
    required this.today,
  });
  final String letter;
  final bool studied;
  final bool today;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        letter,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: studied ? AppColors.streak : Colors.white,
          border: today
              ? Border.all(color: AppColors.primary, width: 2.5)
              : null,
        ),
        child: studied
            ? const Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: Colors.white,
              )
            : null,
      ),
    ],
  );
}

/// Shown when no decks exist yet for the student's class.
class NoContentView extends StatelessWidget {
  const NoContentView({super.key, required this.classLevel});
  final int classLevel;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Tier.of(context).isJunior) const MyOwl(size: 96),
            const SizedBox(height: 12),
            Text(
              'Class $classLevel decks are coming soon',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Decks are available for Classes 1 to 10.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: state.signOut,
              child: const Text('Switch student'),
            ),
          ],
        ),
      ),
    );
  }
}
