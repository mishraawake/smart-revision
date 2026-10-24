import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/account_service.dart';
import '../../data/share.dart';
import '../../models/account.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'adult_widgets.dart';
import 'student_signup_screen.dart';

/// Shown until the parent taps the approval link; then opens Today.
class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key, required this.request});
  final ApprovalRequest request;

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  static const _pollEvery = Duration(seconds: 3);
  static const _resendAfter = 45;

  Timer? _poll;
  Timer? _tick;
  var _wait = _resendAfter;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(_pollEvery, (_) => _check());
    _startResendTimer();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _tick?.cancel();
    _wait = _resendAfter;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _check() async {
    final accounts = AccountScope.read(context);
    final app = AppScope.read(context);
    final (ApprovalRequest, String)? approved;
    try {
      approved = await accounts.checkApproval();
    } on AccountException {
      return; // Offline; the next tick tries again.
    }
    if (approved == null) return;
    _poll?.cancel();
    final (r, childId) = approved;
    final p = await app.addProfile(
      r.name,
      r.classLevel,
      avatar: r.avatar,
      id: childId,
    );
    await app.select(p);
  }

  Future<void> _changeNumber() async {
    final accounts = AccountScope.read(context);
    final nav = Navigator.of(context);
    final r = widget.request;
    await accounts.cancelRequest();
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => Adult(child: StudentSignupScreen(from: r)),
      ),
    );
  }

  String _message(bool demo) => demo
      ? '${widget.request.name} wants to revise with RevUp (Class '
            '${widget.request.classLevel}). Tap the link in the SMS from RevUp '
            'to say yes.'
      : '${widget.request.name} wants to revise with RevUp (Class '
            '${widget.request.classLevel}). Open RevUp, log in as a parent with '
            'this number and tap Approve.';

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final demo = AccountScope.of(context).service.isDemo;
    return FormPage(
      top: 40,
      fields: [
        Center(
          child: SizedBox(
            width: 120,
            height: 112,
            child: Stack(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 56,
                    color: AppColors.onPrimaryTint,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AdultColors.ground, width: 3),
                    ),
                    child: Avatar(name: r.name, index: r.avatar, size: 44),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Waiting for your parent',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: demo
                    ? 'We texted a link to '
                    : 'Ask your parent to open RevUp and log in with ',
              ),
              TextSpan(
                text: maskPhone(r.parentPhone),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              TextSpan(
                text: demo
                    ? '. Ask them to tap it and say yes.'
                    : '. Your request is waiting there.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 24),
        AdultCard(
          child: Column(
            children: [
              _Step(
                state: _StepState.done,
                title: 'Request sent',
                sub: '${r.name} · Class ${r.classLevel} · just now',
              ),
              const SizedBox(height: 14),
              const _Step(
                state: _StepState.current,
                number: 2,
                title: 'Parent approves',
                sub: 'They have 48 hours to say yes',
              ),
              const SizedBox(height: 14),
              const _Step(
                state: _StepState.todo,
                number: 3,
                title: 'Start revising',
                sub: 'This screen opens Today by itself',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.sync, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                demo
                    ? 'Test version: approval comes through by itself in a '
                          'few seconds'
                    : 'Checking for approval every few seconds',
                style: mutedStyle,
              ),
            ),
          ],
        ),
      ],
      bottom: [
        PrimaryButton(
          label: 'Tell them on WhatsApp',
          icon: Icons.share_outlined,
          onPressed: () => shareText(context, _message(demo)),
        ),
        if (demo) ...[
          const SizedBox(height: 10),
          SecondaryButton(
            label: _wait > 0
                ? 'Resend SMS in 0:${_wait.toString().padLeft(2, '0')}'
                : 'Resend SMS',
            onPressed: _wait > 0
                ? null
                : () {
                    setState(_startResendTimer);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SMS sent again')),
                    );
                  },
          ),
        ],
        LinkButton(label: 'Wrong number? Change it', onPressed: _changeNumber),
      ],
    );
  }
}

enum _StepState { done, current, todo }

class _Step extends StatelessWidget {
  const _Step({
    required this.state,
    required this.title,
    required this.sub,
    this.number = 1,
  });

  final _StepState state;
  final int number;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: state == _StepState.done ? AppColors.knew : null,
          border: switch (state) {
            _StepState.done => null,
            _StepState.current => Border.all(
              color: AppColors.primary,
              width: 2.5,
            ),
            _StepState.todo => Border.all(color: AdultColors.field, width: 2),
          },
        ),
        child: state == _StepState.done
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : Text(
                '$number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: state == _StepState.current
                      ? AppColors.onPrimaryTint
                      : AppColors.inkMuted,
                ),
              ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: state == _StepState.todo
                    ? AdultColors.chipInk
                    : AppColors.ink,
              ),
            ),
            Text(sub, style: labelStyle.copyWith(fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      if (state == _StepState.current)
        const StatusChip('Pending', ChipTone.pending),
    ],
  );
}
