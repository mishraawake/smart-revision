import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'adult_widgets.dart';

/// A parent adds a child: first name, class and avatar.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key, this.firstChild = false});

  /// Straight after sign-up, so say more can be added later.
  final bool firstChild;

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _name = TextEditingController();
  int? _class;
  late var _avatar =
      AppScope.read(context).profiles.length % avatarColors.length;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final app = AppScope.read(context);
    await app.addProfile(_name.text, _class!, avatar: _avatar);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return FormPage(
      fields: [
        BackRow(
          icon: widget.firstChild ? Icons.close : Icons.chevron_left,
          trailing: widget.firstChild
              ? const Text('You can add more later', style: labelStyle)
              : null,
        ),
        const SizedBox(height: 8),
        const ScreenTitle('Add a child'),
        const SizedBox(height: 18),
        LabelledField(
          label: "Child's first name",
          controller: _name,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        const Text('Class (CBSE)', style: labelStyle),
        const SizedBox(height: 8),
        ClassPicker(
          classes: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          selected: _class,
          onSelect: (c) => setState(() => _class = c),
        ),
        const SizedBox(height: 8),
        const Text(
          'Classes 1–5 get the Junior look with read-aloud. 6–10 get Senior.',
          style: labelStyle,
        ),
        const SizedBox(height: 18),
        const Text('Pick an avatar', style: labelStyle),
        const SizedBox(height: 10),
        AvatarPicker(
          name: name,
          selected: _avatar,
          onSelect: (i) => setState(() => _avatar = i),
        ),
      ],
      bottom: [
        PrimaryButton(
          label: name.isEmpty ? 'Save profile' : "Save $name's profile",
          onPressed: name.isNotEmpty && _class != null && !_saving
              ? _save
              : null,
        ),
      ],
    );
  }
}
