import 'package:flutter/material.dart';

import '../../models/deck.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../account/adult_widgets.dart';

/// A teacher sets up a class: school, class, section and subject. The join
/// code is made when it is saved.
class AddClassScreen extends StatefulWidget {
  const AddClassScreen({super.key});

  @override
  State<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  static const _sections = ['A', 'B', 'C', 'D', 'E', 'F'];

  late final _school = TextEditingController(
    text: AccountScope.read(context).classes.lastOrNull?.school ?? '',
  );
  int? _class;
  String? _section;
  String? _subjectId;
  Future<ClassDeck?>? _deck;
  var _saving = false;

  @override
  void dispose() {
    _school.dispose();
    super.dispose();
  }

  void _pickClass(int c) => setState(() {
    _class = c;
    _subjectId = null;
    _deck = AppScope.read(context).decks.load(c);
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    await AccountScope.read(context).createClass(
      school: _school.text.trim(),
      classLevel: _class!,
      section: _section!,
      subjectId: _subjectId!,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _school.text.trim().isNotEmpty &&
        _class != null &&
        _section != null &&
        _subjectId != null;
    return FormPage(
      fields: [
        const BackRow(icon: Icons.close),
        const SizedBox(height: 4),
        const ScreenTitle(
          'Add a class',
          subtitle: Text('Students join with a code you share.'),
        ),
        const SizedBox(height: 18),
        LabelledField(
          label: 'School',
          controller: _school,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        const Text('Class (CBSE)', style: labelStyle),
        const SizedBox(height: 8),
        ClassPicker(
          classes: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          selected: _class,
          onSelect: _pickClass,
        ),
        const SizedBox(height: 18),
        const Text('Section', style: labelStyle),
        const SizedBox(height: 8),
        ClassPicker(
          classes: const [0, 1, 2, 3, 4, 5],
          columns: 6,
          selected: _section == null ? null : _sections.indexOf(_section!),
          onSelect: (i) => setState(() => _section = _sections[i]),
          labelOf: (i) => _sections[i],
          semanticPrefix: 'Section',
        ),
        if (_deck != null) ...[
          const SizedBox(height: 18),
          const Text('Subject you teach', style: labelStyle),
          const SizedBox(height: 8),
          FutureBuilder<ClassDeck?>(
            future: _deck,
            builder: (context, snap) {
              final subjects = snap.data?.subjects ?? const <Subject>[];
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(height: 48);
              }
              if (subjects.isEmpty) {
                return const Text(
                  'No decks for this class yet.',
                  style: mutedStyle,
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in subjects)
                    ChoiceButton(
                      label: s.name,
                      selected: s.id == _subjectId,
                      onTap: () => setState(() => _subjectId = s.id),
                    ),
                ],
              );
            },
          ),
        ],
      ],
      bottom: [
        PrimaryButton(
          label: 'Create class',
          onPressed: ready && !_saving ? _save : null,
        ),
      ],
    );
  }
}
