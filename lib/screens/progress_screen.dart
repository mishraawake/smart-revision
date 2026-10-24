import 'package:flutter/material.dart';

import '../logic/levels.dart';
import '../models/deck.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'today_screen.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.deck == null) {
      return NoContentView(classLevel: state.current!.classLevel);
    }
    final junior = Tier.of(context).isJunior;
    final p = state.current!;
    final history = state.quizHistory;
    final t = state.now();
    final thisMonth = history
        .where((q) => q.at.year == t.year && q.at.month == t.month)
        .toList();
    final avg = history.isEmpty
        ? null
        : history.map((q) => q.accuracy).reduce((a, b) => a + b) /
              history.length;

    final sectionTitle = TextStyle(
      fontFamily: junior ? Fonts.display : Fonts.body,
      fontSize: junior ? 22 : 15,
      fontWeight: FontWeight.w800,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                junior ? 'My progress' : 'Progress',
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: junior ? 30 : 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (junior)
              ReadAloudButton(
                'You have ${p.stars} stars and studied '
                '${state.streakOf(p)} days in a row.',
              )
            else
              const SwitchStudentButton(),
          ],
        ),
        const SizedBox(height: 16),
        if (junior)
          Row(
            children: [
              Expanded(
                child: _JuniorStat(
                  icon: const StarIcon(size: 30),
                  value: formatCount(p.stars),
                  label: 'stars',
                  background: AppColors.starBg,
                  foreground: AppColors.starInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _JuniorStat(
                  icon: const FlameIcon(size: 30),
                  value: '${state.streakOf(p)} days',
                  label: 'in a row',
                  background: AppColors.streakBg,
                  foreground: AppColors.streakInk,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              _SeniorStat(value: '${state.streakOf(p)} days', label: 'Streak'),
              const SizedBox(width: 10),
              _SeniorStat(
                value: '${thisMonth.length}',
                label: 'Quizzes in ${months[t.month - 1]}',
              ),
              const SizedBox(width: 10),
              _SeniorStat(
                value: avg == null ? '—' : '${(avg * 100).round()}%',
                label: 'Avg score',
              ),
            ],
          ),
        const SizedBox(height: 24),
        Text(junior ? 'My subjects' : 'Mastery', style: sectionTitle),
        const SizedBox(height: 10),
        for (final s in state.deck!.subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SubjectProgress(subject: s, junior: junior),
          ),
        if (!junior)
          const Text(
            'Mastery = cards you know well plus quiz accuracy, per chapter.',
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
        const SizedBox(height: 24),
        Text(junior ? 'My study days' : 'Study days', style: sectionTitle),
        const SizedBox(height: 10),
        SoftCard(child: _Calendar(junior: junior)),
        const SizedBox(height: 24),
        Text(junior ? 'My quizzes' : 'Quiz history', style: sectionTitle),
        const SizedBox(height: 10),
        if (history.isEmpty)
          Text(
            'No quizzes yet. Open a chapter and tap Quiz.',
            style: TextStyle(
              fontSize: junior ? 18 : 15,
              color: AppColors.inkMuted,
            ),
          )
        else
          for (final q in history.take(junior ? 3 : 5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _QuizRow(record: q, junior: junior),
            ),
      ],
    );
  }
}

class _JuniorStat extends StatelessWidget {
  const _JuniorStat({
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
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: foreground,
                  ),
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
      ],
    ),
  );
}

class _SeniorStat extends StatelessWidget {
  const _SeniorStat({required this.value, required this.label});
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

/// One subject with its chapters. Junior counts quiz stars; Senior shows
/// mastery and expands to chapters.
class _SubjectProgress extends StatefulWidget {
  const _SubjectProgress({required this.subject, required this.junior});
  final Subject subject;
  final bool junior;

  @override
  State<_SubjectProgress> createState() => _SubjectProgressState();
}

class _SubjectProgressState extends State<_SubjectProgress> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = widget.subject;
    final style = SubjectStyle.of(s.id);
    final junior = widget.junior;
    final (stars, maxStars) = state.subjectQuizStars(s);
    final mastery = state.subjectMastery(s);

    String chapterStatus(Chapter ch) {
      final best = state.bestQuiz(ch.id);
      if (junior) {
        return best == null
            ? (state.isStarted(ch) ? 'No quiz yet' : 'Not started')
            : '';
      }
      return state.isStarted(ch)
          ? '${(state.chapterMastery(ch) * 100).round()}%'
          : 'Not started';
    }

    return SoftCard(
      padding: 14,
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SubjectBadge(s.id, size: junior ? 52 : 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        fontFamily: junior ? Fonts.display : Fonts.body,
                        fontSize: junior ? 22 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ProgressBar(
                      junior ? (maxStars == 0 ? 0 : stars / maxStars) : mastery,
                      color: junior ? AppColors.star : style.foreground,
                      height: junior ? 10 : 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (junior)
                Row(
                  children: [
                    const StarIcon(size: 18),
                    Text(
                      ' $stars of $maxStars',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  '${(mastery * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Icon(
                _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppColors.inkMuted,
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            for (final ch in s.chapters)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chapter ${ch.number} · ${ch.title}',
                        style: TextStyle(fontSize: junior ? 16 : 14),
                      ),
                    ),
                    if (junior && state.bestQuiz(ch.id) != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Icon(
                              Icons.star_rounded,
                              size: 20,
                              color:
                                  i <
                                      quizStars(
                                        state.bestQuiz(ch.id)!.score,
                                        state.bestQuiz(ch.id)!.total,
                                      )
                                  ? AppColors.star
                                  : const Color(0xFFE3D8C6),
                            ),
                        ],
                      )
                    else
                      Text(
                        chapterStatus(ch),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// This month's calendar. Junior marks studied days; Senior shades each
/// day by how many cards and questions were done (0 to 40+).
class _Calendar extends StatelessWidget {
  const _Calendar({required this.junior});
  final bool junior;

  static const _heat = [
    Color(0xFFF3EADB),
    Color(0xFFC7D2FE),
    Color(0xFF818CF8),
    Color(0xFF4F46E5),
    Color(0xFF312E81),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = state.now();
    final first = DateTime(t.year, t.month, 1);
    final days = DateTime(t.year, t.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first.
    final labels = junior
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    Widget cell(int day) {
      final date = DateTime(t.year, t.month, day);
      final today = day == t.day;
      final future = date.isAfter(t);
      final count = state.activityOn(date);
      final studied = state.studiedOn(date);
      final Color bg;
      final Color fg;
      if (junior) {
        bg = studied ? AppColors.primary : Colors.white;
        fg = studied
            ? Colors.white
            : (future ? AppColors.groundBorder : AppColors.inkMuted);
      } else {
        final level = count == 0
            ? 0
            : count < 10
            ? 1
            : count < 20
            ? 2
            : count < 40
            ? 3
            : 4;
        bg = future ? Colors.white : _heat[level];
        fg = level >= 3 ? Colors.white : AppColors.ink;
      }
      return Semantics(
        label:
            '${monthNames[t.month - 1]} $day: '
            '${studied ? 'studied, $count cards and questions' : 'rest day'}'
            '${today ? ', today' : ''}',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(junior ? 99 : 8),
            border: today
                ? Border.all(color: AppColors.streak, width: 2.5)
                : null,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: junior ? 14 : 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${monthNames[t.month - 1]}${junior ? '' : ' ${t.year}'}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++) cell(d),
          ],
        ),
        const SizedBox(height: 8),
        if (junior)
          const Wrap(
            spacing: 16,
            children: [
              _Legend(color: AppColors.primary, label: 'Studied'),
              _Legend(color: Colors.white, label: 'Rest day', border: true),
              _Legend(color: Colors.white, label: 'Today', ring: true),
            ],
          )
        else
          Row(
            children: [
              const Text(
                'Cards + questions per day  0 ',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              for (final c in _heat)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const Text(
                ' 40+',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            ],
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.border = false,
    this.ring = false,
  });

  final Color color;
  final String label;
  final bool border;
  final bool ring;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: ring
              ? Border.all(color: AppColors.streak, width: 2.5)
              : border
              ? Border.all(color: AppColors.groundBorder, width: 1.5)
              : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _QuizRow extends StatelessWidget {
  const _QuizRow({required this.record, required this.junior});
  final QuizRecord record;
  final bool junior;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ch = state.chapterById(record.chapterId);
    final subject = ch == null ? null : state.subjectById(ch.subjectId);
    final title = ch == null
        ? 'Mixed quiz'
        : junior
        ? '${subject!.name} · Chapter ${ch.number}'
        : '${subject!.name} · Ch ${ch.number}';
    final when = shortDate(state.now(), record.at);
    return SoftCard(
      padding: 12,
      child: Row(
        children: [
          SubjectBadge(ch?.subjectId ?? '', size: junior ? 44 : 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: junior ? 17 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  junior ? '$when · ${record.score} of ${record.total}' : when,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (junior)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: i < quizStars(record.score, record.total)
                        ? AppColors.star
                        : const Color(0xFFE3D8C6),
                  ),
              ],
            )
          else
            Text(
              '${record.score}/${record.total}  '
              '${(record.accuracy * 100).round()}%',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}
