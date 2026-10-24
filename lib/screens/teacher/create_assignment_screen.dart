import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/deck.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/format.dart';
import '../account/adult_widgets.dart';

/// T2: pick deck or quiz, a chapter and a due date.
class CreateAssignmentScreen extends StatefulWidget {
  const CreateAssignmentScreen({super.key, required this.deck});

  final ClassDeck deck;

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  var _kind = AssignmentKind.quiz;
  late String _subjectId;
  String? _chapterId;
  late DateTime _today;
  late DateTime _due;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final c = AccountScope.read(context).currentClass!;
    final subjects = widget.deck.subjects;
    _subjectId = subjects.any((s) => s.id == c.subjectId)
        ? c.subjectId
        : subjects.first.id;
    final now = AppScope.read(context).now();
    _today = DateTime(now.year, now.month, now.day);
    _due = _today.add(const Duration(days: 1));
  }

  DateTime get _inAWeek => _today.add(const Duration(days: 5));

  String _day(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = AppScope.read(context).now();
    await AccountScope.read(context).addAssignment(
      Assignment(
        id: '${now.microsecondsSinceEpoch}',
        kind: _kind,
        subjectId: _subjectId,
        chapterId: _chapterId!,
        due: DateTime(_due.year, _due.month, _due.day, 23, 59),
        createdAt: now,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AccountScope.of(context).currentClass!;
    final subject = widget.deck.subjects.firstWhere((s) => s.id == _subjectId);
    final assigned = {
      for (final a in c.assignments)
        if (a.kind == _kind && a.cardIds == null) a.chapterId,
    };
    final students = c.approved.length;
    final tomorrow = _today.add(const Duration(days: 1));
    final custom = _due != tomorrow && _due != _inAWeek;

    return FormPage(
      fields: [
        const BackRow(icon: Icons.close),
        const SizedBox(height: 4),
        ScreenTitle(
          'New assignment',
          subtitle: Text('${c.label} · $students students'),
        ),
        const SizedBox(height: 20),
        const Text('What to assign', style: labelStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceButton(
                label: 'Chapter deck',
                sub: 'Flashcards',
                icon: Icons.style_outlined,
                selected: _kind == AssignmentKind.deck,
                onTap: () => setState(() => _kind = AssignmentKind.deck),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceButton(
                label: 'Quiz',
                sub: '10 questions, scored',
                icon: Icons.quiz_outlined,
                selected: _kind == AssignmentKind.quiz,
                onTap: () => setState(() => _kind = AssignmentKind.quiz),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Chapter', style: labelStyle),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in widget.deck.subjects) ...[
                if (s != widget.deck.subjects.first) const SizedBox(width: 8),
                ChoiceButton(
                  label: s.name,
                  selected: s.id == _subjectId,
                  onTap: () => setState(() {
                    _subjectId = s.id;
                    _chapterId = null;
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        AdultCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final ch in subject.chapters)
                _ChapterRow(
                  chapter: ch,
                  assigned: assigned.contains(ch.id),
                  selected: ch.id == _chapterId,
                  onTap: () => setState(() => _chapterId = ch.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Due date', style: labelStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceButton(
                label: 'Tomorrow',
                sub: _day(tomorrow),
                selected: _due == tomorrow,
                onTap: () => setState(() => _due = tomorrow),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceButton(
                label: _day(_inAWeek),
                sub: months[_inAWeek.month - 1],
                selected: _due == _inAWeek,
                onTap: () => setState(() => _due = _inAWeek),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceButton(
                label: custom ? _day(_due) : 'Pick',
                sub: custom ? months[_due.month - 1] : null,
                icon: custom ? null : Icons.calendar_today_outlined,
                selected: custom,
                onTap: _pickDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Due by 11:59 pm. Students see it at the top of Today.',
          style: labelStyle,
        ),
      ],
      bottom: [
        PrimaryButton(
          label:
              'Assign ${_kind == AssignmentKind.quiz ? 'quiz' : 'deck'} '
              'to $students students',
          onPressed: _chapterId != null && !_saving ? _save : null,
        ),
      ],
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.assigned,
    required this.selected,
    required this.onTap,
  });

  final Chapter chapter;
  final bool assigned;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: ListTile(
      minTileHeight: 56,
      enabled: !assigned,
      onTap: onTap,
      selected: selected,
      selectedTileColor: AppColors.primaryTint,
      leading: Text(
        'Ch ${chapter.number}',
        style: labelStyle.copyWith(fontSize: 14),
      ),
      title: Text(
        chapter.title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      trailing: assigned
          ? const StatusChip('Assigned', ChipTone.pending)
          : selected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : Text('${chapter.cards.length} cards', style: labelStyle),
    ),
  );
}
