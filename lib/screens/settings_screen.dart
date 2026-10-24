import 'package:flutter/material.dart';

import '../data/speaker.dart';
import '../firebase/environment.dart';
import '../models/account.dart';
import '../state/account_state.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'account/adult_widgets.dart';

/// Grown-up settings: account, feedback, read-aloud speed, log out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = AccountScope.of(context);
    final app = AppScope.of(context);
    final account = accounts.account;
    final s = accounts.settings;
    final kids = app.profiles.length;

    final who = switch (account?.role) {
      Role.teacher =>
        'Teacher · ${accounts.classes.length} '
            '${accounts.classes.length == 1 ? 'class' : 'classes'}',
      Role.student => 'Student',
      _ => 'Parent · $kids ${kids == 1 ? 'child' : 'children'}',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              const BackRow(),
              const SizedBox(width: 4),
            ],
            const Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdultCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.onPrimaryTint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.phone == null
                          ? 'Not signed in'
                          : '+91 ${formatPhone(account!.phone!)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(who, style: labelStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Heading('Answers'),
        AdultCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Vibrate on answer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            value: s.vibrate,
            onChanged: (v) => accounts.updateSettings((s) => s.vibrate = v),
          ),
        ),
        const SizedBox(height: 24),
        const _Heading('Read-aloud speed'),
        AdultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Segments(
                labels: const ['Slow', 'Normal', 'Fast'],
                index: s.speed.index,
                onChanged: (i) => accounts.updateSettings(
                  (s) => s.speed = SpeechSpeed.values[i],
                ),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Play a sample',
                icon: Icons.volume_up_outlined,
                onPressed: () =>
                    SpeakerScope.of(context)
                        .say('Photosynthesis is how plants make food.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Heading('Downloads'),
        const AdultCard(
          child: Row(
            children: [
              Icon(Icons.offline_pin_outlined, color: AppColors.knew),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Every chapter is built into the app, so it all works '
                  'offline. Nothing to download.',
                  style: TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SecondaryButton(
          label: 'Log out',
          icon: Icons.logout,
          onPressed: () => _logOut(context),
        ),
        const SizedBox(height: 12),
        _VersionLine(demo: accounts.service.isDemo),
      ],
    );
  }

  Future<void> _logOut(BuildContext context) async {
    final accounts = AccountScope.read(context);
    final app = AppScope.read(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          "Progress stays on this phone. You'll need your mobile number to "
          'log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    nav.popUntil((r) => r.isFirst);
    app.signOut();
    await accounts.signOut();
  }
}

/// "RevUp". Seven taps opens the hidden staging/production switch.
class _VersionLine extends StatefulWidget {
  const _VersionLine({required this.demo});
  final bool demo;

  @override
  State<_VersionLine> createState() => _VersionLineState();
}

class _VersionLineState extends State<_VersionLine> {
  static const _tapsNeeded = 7;
  var _taps = 0;

  Future<void> _tap() async {
    if (++_taps < _tapsNeeded) return;
    _taps = 0;
    final code = TextEditingController();
    final env = await showDialog<AppEnv>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final ok = code.text == Environment.switchCode;
          return AlertDialog(
            title: const Text('Developer: environment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Now on ${Environment.current?.name ?? 'none'}.'),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Code'),
                  onChanged: (_) => setDialog(() {}),
                ),
                if (ok) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Switching clears all data on this phone, signs out and '
                    'closes the app. Reopen it to continue.',
                    style: mutedStyle,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              for (final e in AppEnv.values)
                if (ok && e != Environment.current)
                  FilledButton(
                    onPressed: () => Navigator.pop(context, e),
                    child: Text(
                      e == AppEnv.prod ? 'Use production' : 'Use staging',
                    ),
                  ),
            ],
          );
        },
      ),
    );
    code.dispose();
    if (env != null) await Environment.switchTo(env);
  }

  @override
  Widget build(BuildContext context) {
    final env = Environment.isStaging ? ' · staging' : '';
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          widget.demo ? 'RevUp · test version$env' : 'RevUp$env',
          textAlign: TextAlign.center,
          style: labelStyle,
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}
