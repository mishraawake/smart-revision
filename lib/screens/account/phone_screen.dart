import 'package:flutter/material.dart';

import '../../data/account_service.dart';
import '../../models/account.dart';
import '../../state/account_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'adult_widgets.dart';
import 'otp_screen.dart';

String roleLabel(Role role, {bool login = false}) => login
    ? 'Log in'
    : switch (role) {
        Role.parent => 'Parent',
        Role.teacher => 'Teacher',
        Role.student => 'Student',
      };

/// Mobile number, plus consent when a parent or teacher signs up.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, required this.role, this.login = false});

  final Role role;

  /// Returning user: no consent box, whatever role they had.
  final bool login;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phone = TextEditingController();
  var _agreed = false;
  var _sending = false;

  bool get _needsConsent => !widget.login;
  bool get _valid =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text) &&
      (_agreed || !_needsConsent);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final accounts = AccountScope.read(context);
    try {
      await accounts.service.sendOtp(_phone.text);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAccountError(context, e);
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await pushAdult(
      context,
      OtpScreen(role: widget.role, phone: _phone.text, login: widget.login),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showError =
        _phone.text.length == 10 && !RegExp(r'^[6-9]').hasMatch(_phone.text);
    return FormPage(
      fields: [
        BackRow(
          trailing: RolePill(roleLabel(widget.role, login: widget.login)),
        ),
        const SizedBox(height: 16),
        const ScreenTitle(
          'Your mobile number',
          subtitle: Text("We'll text you a 6-digit code. No password needed."),
        ),
        const SizedBox(height: 24),
        PhoneField(
          controller: _phone,
          label: 'Mobile number',
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        if (showError) ...[
          const SizedBox(height: 6),
          const Text(
            'Indian mobile numbers start with 6, 7, 8 or 9.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.againInk,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_needsConsent)
          AdultCard(
            padding: const EdgeInsets.all(14),
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.role == Role.parent
                        ? "I'm the parent or guardian. I agree to the Terms "
                              'and Privacy Policy, and consent to RevUp '
                              "storing my children's study progress."
                        : 'I agree to the Terms and Privacy Policy, and to '
                              "RevUp storing my class's progress.",
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.role == Role.teacher
                    ? 'Your number is only used to log in. We never show it '
                          'to students or parents.'
                    : "Your number is only used to log in and approve your "
                          "child's account. We never show it to teachers or "
                          'other students.',
                style: mutedStyle,
              ),
            ),
          ],
        ),
      ],
      bottom: [
        PrimaryButton(
          label: _sending ? 'Sending…' : 'Send OTP',
          onPressed: _valid && !_sending ? _send : null,
        ),
        const SizedBox(height: 10),
        const Text(
          'Standard SMS rates may apply.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
