import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../state/account_state.dart';
import '../../widgets/common.dart';
import 'adult_widgets.dart';

/// Classes 6–10 sign themselves up; a parent approves by SMS link.
class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key, this.from});

  /// A request being redone after "Wrong number?".
  final ApprovalRequest? from;

  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  late final _name = TextEditingController(text: widget.from?.name);
  late final _phone = TextEditingController(text: widget.from?.parentPhone);
  late int? _class = widget.from?.classLevel;
  late var _avatar = widget.from?.avatar ?? 3;
  var _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _class != null &&
      RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text);

  Future<void> _ask() async {
    setState(() => _sending = true);
    final accounts = AccountScope.read(context);
    final nav = Navigator.of(context);
    await accounts.requestApproval(
      name: _name.text.trim(),
      classLevel: _class!,
      avatar: _avatar,
      parentPhone: _phone.text,
    );
    // The app's home is now the waiting screen.
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => FormPage(
    fields: [
      const BackRow(trailing: RolePill('Student · Classes 6–10')),
      const SizedBox(height: 8),
      const ScreenTitle(
        'Create your profile',
        subtitle: Text('A parent says yes before you start.'),
      ),
      const SizedBox(height: 20),
      LabelledField(
        label: 'Your first name',
        controller: _name,
        autofillHints: const [AutofillHints.givenName],
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 18),
      const Text('Your class', style: labelStyle),
      const SizedBox(height: 8),
      ClassPicker(
        classes: const [6, 7, 8, 9, 10],
        selected: _class,
        onSelect: (c) => setState(() => _class = c),
      ),
      const SizedBox(height: 18),
      const Text('Avatar', style: labelStyle),
      const SizedBox(height: 10),
      AvatarPicker(
        name: _name.text.trim(),
        selected: _avatar,
        onSelect: (i) => setState(() => _avatar = i),
      ),
      const SizedBox(height: 18),
      PhoneField(
        controller: _phone,
        label: "Parent's mobile number",
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      const Text(
        "We'll text them a link to approve. Their number is never shown to "
        'anyone else.',
        style: mutedStyle,
      ),
    ],
    bottom: [
      PrimaryButton(
        label: _sending ? 'Sending…' : 'Ask my parent',
        onPressed: _valid && !_sending ? _ask : null,
      ),
    ],
  );
}
