import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/share.dart';
import '../../models/account.dart';
import '../../models/deck.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/format.dart';
import '../account/adult_widgets.dart';
import 'add_class_screen.dart';
import 'assignment_results_screen.dart';
import 'create_assignment_screen.dart';
import 'teacher_shell.dart';

/// One class: join code, assignments and students.
class ClassScreen extends StatelessWidget {
  const ClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = AccountScope.of(context);
    final c = accounts.currentClass;
    if (c == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ScreenTitle(
            'Your classes',
            subtitle: Text('Create a class to get a join code.'),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Add a class',
            onPressed: () => pushAdult(context, const AddClassScreen()),
          ),
        ],
      );
    }
    final app = AppScope.of(context);
    return FutureBuilder<ClassDeck?>(
      future: app.decks.load(c.classLevel),
      builder: (context, snap) =>
          _ClassBody(teacherClass: c, deck: snap.data, now: app.now()),
    );
  }
}

class _ClassBody extends StatefulWidget {
  const _ClassBody({
    required this.teacherClass,
    required this.deck,
    required this.now,
  });

  final TeacherClass teacherClass;
  final ClassDeck? deck;
  final DateTime now;

  @override
  State<_ClassBody> createState() => _ClassBodyState();
}

class _ClassBodyState extends State<_ClassBody> {
  static const _shown = 5;
  var _allStudents = false;

  void _switchClass() {
    final accounts = AccountScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < accounts.classes.length; i++)
              ListTile(
                minTileHeight: 56,
                title: Text(
                  accounts.classes[i].label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(accounts.classes[i].school),
                trailing: i == accounts.classIndex
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  accounts.selectClass(i);
                  Navigator.pop(sheet);
                },
              ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.add),
              title: const Text(
                'Add a class',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                Navigator.pop(sheet);
                pushAdult(context, const AddClassScreen());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.teacherClass;
    final deck = widget.deck;
    final subject = deck?.subjects
        .where((s) => s.id == c.subjectId)
        .firstOrNull;
    final joined = c.students.length;
    final students = [...c.students]
      ..sort((a, b) {
        if (a.awaitingParent != b.awaitingParent) {
          return a.awaitingParent ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Switch class. Current: ${c.label}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: _switchClass,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.school} · ${subject?.name ?? c.subjectId}',
                          style: labelStyle,
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.label,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Add a class',
              onPressed: () => pushAdult(context, const AddClassScreen()),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                side: const BorderSide(color: AdultColors.field, width: 1.5),
                backgroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                'Class join code',
                trailing: Text(
                  c.size > 0 ? '$joined of ${c.size} joined' : '$joined joined',
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Join code ${c.joinCode.split('').join(' ')}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 0; i < c.joinCode.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            c.joinCode[i],
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimaryTint,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Copy',
                      icon: Icons.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.joinCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Join code copied')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Share code',
                      icon: Icons.share_outlined,
                      onPressed: () => shareText(
                        context,
                        'Join ${c.label} on RevUp with the code '
                        '${c.joinCode}.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Students enter this in the app. Their parent approves '
                'before they appear here.',
                style: labelStyle.copyWith(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                'Assignments',
                trailing: TextButton.icon(
                  onPressed: deck == null
                      ? null
                      : () => pushAdult(
                          context,
                          CreateAssignmentScreen(deck: deck),
                        ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'New',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              if (c.assignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Nothing set yet. Tap New to assign a chapter deck or '
                    'a quiz.',
                    style: mutedStyle,
                  ),
                ),
              for (final a in c.assignments)
                if (deck?.chapters
                        .where((ch) => ch.id == a.chapterId)
                        .firstOrNull
                    case final ch?)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _AssignmentTile(
                      teacherClass: c,
                      assignment: a,
                      chapter: ch,
                      subject: deck!.subjects.firstWhere(
                        (s) => s.id == ch.subjectId,
                      ),
                      now: widget.now,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                'Students · ${c.approved.length}',
                trailing: students.length > _shown
                    ? TextButton(
                        onPressed: () =>
                            setState(() => _allStudents = !_allStudents),
                        child: Text(
                          _allStudents ? 'Show fewer' : 'See all',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      )
                    : null,
              ),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'No one has joined yet. Share the code with your class.',
                    style: mutedStyle,
                  ),
                ),
              for (final s in _allStudents ? students : students.take(_shown))
                _StudentRow(student: s, now: widget.now),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.teacherClass,
    required this.assignment,
    required this.chapter,
    required this.subject,
    required this.now,
  });

  final TeacherClass teacherClass;
  final Assignment assignment;
  final Chapter chapter;
  final Subject subject;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final service = AccountScope.of(context).service;
    final a = assignment;
    final kind = a.kind == AssignmentKind.quiz ? 'Quiz' : 'Deck';
    final due = dueLabel(now, a.due);
    final today = due == 'Due today';
    return FutureBuilder<AssignmentResults>(
      future: service.results(teacherClass, a, chapter),
      builder: (context, snap) {
        final r = snap.data;
        final total = teacherClass.approved.length;
        final done = r?.done.length ?? 0;
        return Material(
          color: AdultColors.ground,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => pushAdult(
              context,
              AssignmentResultsScreen(
                teacherClass: teacherClass,
                assignment: a,
                chapter: chapter,
                subject: subject,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$kind · ${subject.name} Ch ${chapter.number}',
                          style: labelStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        due,
                        today ? ChipTone.needsWork : ChipTone.pending,
                      ),
                    ],
                  ),
                  Text(
                    chapter.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ProgressBar(
                          total == 0 ? 0 : done / total,
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$done/$total done', style: labelStyle),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.now});

  final ClassStudent student;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final active = s.lastActive == null
        ? 'Joined with code'
        : 'Active ${shortDate(now, s.lastActive!).toLowerCase()}';
    final m = s.mastery;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryTint,
            child: Text(
              s.initials,
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
                  s.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(active, style: labelStyle),
              ],
            ),
          ),
          if (s.awaitingParent)
            const StatusChip('Awaiting parent', ChipTone.pending)
          else if (m != null)
            StatusChip(
              '${(m * 100).round()}%',
              m >= 0.8
                  ? ChipTone.mastered
                  : m < 0.6
                  ? ChipTone.needsWork
                  : ChipTone.pending,
            ),
        ],
      ),
    );
  }
}
