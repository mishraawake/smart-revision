import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_service.dart';
import '../models/account.dart';
import '../models/profile.dart';
import '../state/account_state.dart';

/// Asks for a teacher's six-character code and joins [profile] to that
/// class. Returns true when they joined.
Future<bool> showJoinClassDialog(BuildContext context, Profile profile) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _JoinClassDialog(profile: profile),
    ) ??
    false;

class _JoinClassDialog extends StatefulWidget {
  const _JoinClassDialog({required this.profile});
  final Profile profile;

  @override
  State<_JoinClassDialog> createState() => _JoinClassDialogState();
}

class _JoinClassDialogState extends State<_JoinClassDialog> {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = widget.profile;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await AccountScope.read(context).joinClass(
        _code.text,
        ChildRecord(
          id: p.id,
          name: p.name,
          classLevel: p.classLevel,
          avatar: p.avatar,
        ),
      );
      if (!mounted) return;
      switch (r) {
        case JoinResult.joined || JoinResult.alreadyIn:
          nav.pop(true);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                r == JoinResult.joined
                    ? '${p.name} joined the class'
                    : '${p.name} is already in that class',
              ),
            ),
          );
        case JoinResult.badCode:
          setState(
            () => _error = 'No class has that code. Check with the teacher.',
          );
        case JoinResult.wrongClass:
          setState(
            () => _error =
                "That code is for a different class, not Class ${p.classLevel}.",
          );
      }
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Join a class for ${widget.profile.name}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Type the 6-letter code from the teacher."),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            TextInputFormatter.withFunction(
              (_, v) => v.copyWith(text: v.text.toUpperCase()),
            ),
          ],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
          ),
          decoration: InputDecoration(labelText: 'Code', errorText: _error),
          onChanged: (_) => setState(() => _error = null),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _code.text.length == 6 && !_busy ? _join : null,
        child: Text(_busy ? 'Joining…' : 'Join'),
      ),
    ],
  );
}
