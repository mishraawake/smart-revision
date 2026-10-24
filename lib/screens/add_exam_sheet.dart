import 'package:flutter/material.dart';

import '../models/deck.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// "Got a test coming?" Subject, date and the chapters it covers. The app
/// then plans revision towards it.
Future<void> showAddExamSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.ground,
      builder: (_) => const _AddExamSheet(),
    );

class _AddExamSheet extends StatefulWidget {
  const _AddExamSheet();

  @override
  State<_AddExamSheet> createState() => _AddExamSheetState();
}

class _AddExamSheetState extends State<_AddExamSheet> {
  Subject? _subject;
  DateTime? _day;
  final _chapters = <String>{};

  void _pickSubject(Subject s) {
    final app = AppScope.read(context);
    setState(() {
      _subject = s;
      // Start from what's been done at school.
      _chapters
        ..clear()
        ..addAll([
          for (final ch in s.chapters)
            if (app.current!.covered.contains(ch.id)) ch.id,
        ]);
    });
  }

  Future<void> _pickDay() async {
    final now = AppScope.read(context).now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _day ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
      helpText: 'Test date',
    );
    if (d != null) setState(() => _day = d);
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    await AppScope.read(context)
        .addExam(_subject!.id, _day!, _chapters.toList());
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final deck = AppScope.of(context).deck;
    final subjects = deck?.subjects ?? const <Subject>[];
    final s = _subject;
    final d = _day;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text(
                'Add a test',
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Ollie will plan your revision so you're ready on the day.",
                style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              const _Label('Subject'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sub in subjects)
                    ChoiceChip(
                      label: Text(sub.name),
                      selected: sub == s,
                      onSelected: (_) => _pickSubject(sub),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const _Label('Date'),
              OutlinedButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.event_rounded),
                label: Text(d == null ? 'Pick the test date' : dateLabel(d)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
              ),
              if (s != null) ...[
                const SizedBox(height: 16),
                const _Label('Chapters in the test'),
                for (final ch in s.chapters)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _chapters.contains(ch.id),
                    onChanged: (v) => setState(
                      () => v! ? _chapters.add(ch.id) : _chapters.remove(ch.id),
                    ),
                    title: Text('Ch ${ch.number} · ${ch.title}'),
                  ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Save test',
                onPressed: s != null && d != null && _chapters.isNotEmpty
                    ? _save
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );
}
