import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/deck.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/format.dart';
import '../account/adult_widgets.dart';
import 'teacher_shell.dart';

/// T3: who finished, the class average and the questions most got wrong.
class AssignmentResultsScreen extends StatefulWidget {
  const AssignmentResultsScreen({
    super.key,
    required this.teacherClass,
    required this.assignment,
    required this.chapter,
    required this.subject,
  });

  final TeacherClass teacherClass;
  final Assignment assignment;
  final Chapter chapter;
  final Subject subject;

  @override
  State<AssignmentResultsScreen> createState() =>
      _AssignmentResultsScreenState();
}

class _AssignmentResultsScreenState extends State<AssignmentResultsScreen> {
  static const _weakest = 3;

  late final Future<AssignmentResults> _results = AccountScope.read(context)
      .service
      .results(widget.teacherClass, widget.assignment, widget.chapter);
  var _tab = 0;
  var _reminded = false;

  Future<void> _remind(int count) async {
    await AccountScope.read(context).service
        .remind(widget.teacherClass, widget.assignment);
    if (!mounted) return;
    setState(() => _reminded = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder sent to $count ${count == 1 ? 'student' : 'students'}',
        ),
      ),
    );
  }

  Future<void> _assignRevision(List<QuestionStat> weak) async {
    final accounts = AccountScope.read(context);
    final now = AppScope.read(context).now();
    final today = DateTime(now.year, now.month, now.day);
    await accounts.addAssignment(
      Assignment(
        id: '${now.microsecondsSinceEpoch}',
        kind: AssignmentKind.deck,
        subjectId: widget.assignment.subjectId,
        chapterId: widget.assignment.chapterId,
        due: today.add(const Duration(days: 2, hours: 23, minutes: 59)),
        createdAt: now,
        cardIds: [for (final q in weak) q.cardId],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Revision deck of ${weak.length} cards assigned to '
          '${widget.teacherClass.shortLabel}',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final c = widget.teacherClass;
    final now = AppScope.of(context).now();
    final quiz = a.kind == AssignmentKind.quiz;
    final due = dueLabel(now, a.due);
    final dueLine = due == 'Due today' ? 'Due today, 11:59 pm' : due;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<AssignmentResults>(
          future: _results,
          builder: (context, snap) {
            final r = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const BackRow(),
                Text(
                  '${quiz ? 'Quiz' : 'Deck'} · ${widget.subject.name} '
                  'Ch ${widget.chapter.number} · ${c.shortLabel}',
                  style: labelStyle,
                ),
                const SizedBox(height: 2),
                ScreenTitle(widget.chapter.title, subtitle: Text(dueLine)),
                const SizedBox(height: 16),
                if (r == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _Stats(results: r, students: c.approved.length, quiz: quiz),
                  if (quiz && r.questions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _WeakQuestions(
                      questions: r.questions.take(_weakest).toList(),
                      onAssign: () =>
                          _assignRevision(r.questions.take(_weakest).toList()),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Segments(
                    labels: [
                      'Done · ${r.done.length}',
                      'Not yet · ${r.notYet.length}',
                    ],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 8),
                  if (_tab == 0) ...[
                    if (r.done.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No one has finished yet.',
                          style: mutedStyle,
                        ),
                      ),
                    for (final d in r.done)
                      _Row(
                        student: d.student,
                        when: _finished(now, d.finishedAt),
                        trailing: quiz
                            ? _ScoreChip(d.score, d.total)
                            : const StatusChip('Done', ChipTone.mastered),
                      ),
                  ] else ...[
                    if (r.notYet.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Everyone has finished.',
                          style: mutedStyle,
                        ),
                      ),
                    for (final s in r.notYet)
                      _Row(
                        student: s,
                        when: s.lastActive == null
                            ? 'Not started'
                            : 'Last active ${shortDate(now, s.lastActive!).toLowerCase()}',
                      ),
                  ],
                  if (r.notYet.isNotEmpty &&
                      AccountScope.of(context).service.canRemind) ...[
                    const SizedBox(height: 16),
                    SecondaryButton(
                      label: _reminded
                          ? 'Reminder sent'
                          : "Remind the ${r.notYet.length} who haven't started",
                      icon: _reminded
                          ? Icons.check
                          : Icons.notifications_outlined,
                      onPressed: _reminded
                          ? null
                          : () => _remind(r.notYet.length),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// "4:10 pm" today, otherwise "Yesterday" or the date.
  static String _finished(DateTime now, DateTime t) {
    final day = shortDate(now, t);
    if (day != 'Today') return day;
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.results,
    required this.students,
    required this.quiz,
  });

  final AssignmentResults results;
  final int students;
  final bool quiz;

  @override
  Widget build(BuildContext context) {
    final r = results;
    final done = r.done.length;
    final total = r.done.firstOrNull?.total ?? 10;
    final scores = [for (final d in r.done) d.score];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AdultCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Completed', style: labelStyle),
                const SizedBox(height: 4),
                Text(
                  '$done of $students',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ProgressBar(students == 0 ? 0 : done / students, height: 6),
              ],
            ),
          ),
        ),
        if (quiz) ...[
          const SizedBox(width: 10),
          Expanded(
            child: AdultCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Average score', style: labelStyle),
                  const SizedBox(height: 4),
                  Text(
                    done == 0
                        ? '–'
                        : '${r.averageScore.toStringAsFixed(1)} / $total',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (scores.isNotEmpty)
                    Text(
                      'Range ${scores.reduce(min)}–${scores.reduce(max)}',
                      style: labelStyle,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeakQuestions extends StatelessWidget {
  const _WeakQuestions({required this.questions, required this.onAssign});

  final List<QuestionStat> questions;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) => AdultCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Weakest questions',
          trailing: Text('% answered right', style: labelStyle),
        ),
        for (final q in questions)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('Q${q.number}', style: labelStyle),
                    ),
                    Expanded(
                      child: Text(
                        q.text,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      '${(q.rightShare * 100).round()}%',
                      q.rightShare < 0.6
                          ? ChipTone.needsWork
                          : ChipTone.pending,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: ProgressBar(q.rightShare, height: 6),
                ),
                if (q.commonWrong != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 6),
                    child: Text(
                      'Most picked wrong answer: ${q.commonWrong}',
                      style: labelStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        SecondaryButton(
          label: 'Assign these ${questions.length} as a revision deck',
          icon: Icons.style_outlined,
          onPressed: onAssign,
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.student, required this.when, this.trailing});

  final ClassStudent student;
  final String when;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryTint,
          child: Text(
            student.initials,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimaryTint,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(when, style: labelStyle),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip(this.score, this.total);

  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0 : score / total;
    return StatusChip(
      '$score/$total',
      share >= 0.8
          ? ChipTone.mastered
          : share < 0.5
          ? ChipTone.needsWork
          : ChipTone.pending,
    );
  }
}
