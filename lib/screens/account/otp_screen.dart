import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/account_service.dart';
import '../../models/account.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'add_child_screen.dart';
import 'adult_widgets.dart';
import 'phone_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.role,
    required this.phone,
    this.login = false,
  });

  final Role role;
  final String phone;
  final bool login;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _resendAfter = 30;

  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  var _wait = _resendAfter;
  var _checking = false;
  var _wrong = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _wait = _resendAfter;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _resend({bool call = false}) async {
    final accounts = AccountScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await accounts.service.sendOtp(widget.phone, call: call);
    } on AccountException catch (e) {
      if (mounted) showAccountError(context, e);
      return;
    }
    if (!mounted) return;
    setState(_startTimer);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          call ? "We're calling you with the code" : 'New code sent',
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _checking) return;
    setState(() {
      _checking = true;
      _wrong = false;
    });
    final accounts = AccountScope.read(context);
    final app = AppScope.read(context);
    final nav = Navigator.of(context);
    final bool ok;
    try {
      ok = await accounts.service.verifyOtp(widget.phone, _code.text);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      showAccountError(context, e);
      return;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _checking = false;
        _wrong = true;
        _code.clear();
      });
      _focus.requestFocus();
      return;
    }
    try {
      await accounts.signIn(widget.role, widget.phone);
      if (widget.role == Role.parent) {
        // Children saved from another phone come back.
        for (final c in await accounts.loadChildren()) {
          if (app.profiles.any((p) => p.id == c.id)) continue;
          await app.addProfile(
            c.name,
            c.classLevel,
            avatar: c.avatar,
            id: c.id,
          );
        }
        await accounts.loadRequests();
      }
    } on AccountException catch (e) {
      await accounts.service.signOut();
      if (!mounted) return;
      setState(() => _checking = false);
      showAccountError(context, e);
      return;
    }
    nav.popUntil((r) => r.isFirst);
    if (widget.role == Role.parent && app.profiles.isEmpty) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Adult(child: AddChildScreen(firstChild: true)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = AccountScope.of(context).service.demoOtp;
    return FormPage(
      fields: [
        BackRow(
          trailing: RolePill(roleLabel(widget.role, login: widget.login)),
        ),
        const SizedBox(height: 16),
        ScreenTitle(
          'Enter the code',
          subtitle: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Sent by SMS to '),
                TextSpan(
                  text: '+91 ${formatPhone(widget.phone)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const TextSpan(text: '. '),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: LinkButton(
            label: 'Change number',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(height: 8),
        const Text('6-digit code', style: labelStyle),
        const SizedBox(height: 10),
        _CodeBoxes(
          controller: _code,
          focus: _focus,
          error: _wrong,
          onChanged: (v) {
            setState(() => _wrong = false);
            if (v.length == 6) _verify();
          },
        ),
        if (_wrong) ...[
          const SizedBox(height: 8),
          const Text(
            "That code didn't match. Try again.",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.againInk,
            ),
          ),
        ],
        const SizedBox(height: 20),
        InfoNote(
          demo != null
              ? 'Test version: no SMS is sent. Enter $demo.'
              : 'On Android the code fills in by itself when the SMS arrives.',
          icon: Icons.sms_outlined,
          white: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              "Didn't get it?",
              style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
            ),
            const Spacer(),
            LinkButton(
              label: _wait > 0
                  ? 'Resend in 0:${_wait.toString().padLeft(2, '0')}'
                  : 'Resend code',
              onPressed: _wait > 0 ? null : _resend,
            ),
          ],
        ),
      ],
      bottom: [
        PrimaryButton(
          label: _checking ? 'Checking…' : 'Verify and continue',
          onPressed: _code.text.length == 6 && !_checking ? _verify : null,
        ),
        const SizedBox(height: 4),
        LinkButton(
          label: 'Get the code by phone call',
          onPressed: _wait > 0 ? null : () => _resend(call: true),
        ),
      ],
    );
  }
}

/// Six boxes over one hidden field, so paste and SMS autofill work.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.error,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ListenableBuilder(
        listenable: Listenable.merge([controller, focus]),
        builder: (context, _) {
          final text = controller.text;
          return Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: error
                            ? AppColors.againBorder
                            : focus.hasFocus && i == text.length
                            ? AppColors.primary
                            : AdultColors.field,
                        width: focus.hasFocus && i == text.length ? 2.5 : 1.5,
                      ),
                    ),
                    child: Text(
                      i < text.length ? text[i] : '',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      Positioned.fill(
        child: Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            showCursor: false,
            enableInteractiveSelection: false,
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            style: const TextStyle(fontSize: 1),
          ),
        ),
      ),
    ],
  );
}
