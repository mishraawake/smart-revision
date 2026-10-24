import 'package:flutter/material.dart';

import 'data/speaker.dart';
import 'firebase/environment.dart';
import 'models/account.dart';
import 'screens/onboarding_screen.dart';
import 'screens/account/waiting_screen.dart';
import 'screens/home_shell.dart';
import 'screens/parent/parent_shell.dart';
import 'screens/profile_picker_screen.dart';
import 'screens/teacher/teacher_shell.dart';
import 'state/account_state.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart';

class SmartRevisionApp extends StatelessWidget {
  const SmartRevisionApp({
    super.key,
    required this.state,
    required this.accounts,
    required this.speaker,
  });

  final AppState state;
  final AccountState accounts;
  final Speaker speaker;

  @override
  Widget build(BuildContext context) => SpeakerScope(
    speaker: speaker,
    child: AppScope(
      state: state,
      child: AccountScope(
        state: accounts,
        child: ListenableBuilder(
          listenable: Listenable.merge([state, accounts]),
          builder: (context, _) {
            final junior = state.current?.isJunior ?? state.lastWasJunior;
            return MaterialApp(
              title: 'RevUp',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(junior ? Tier.junior : Tier.senior),
              builder: (context, child) => Environment.isStaging
                  ? Banner(
                      message: 'STAGING',
                      location: BannerLocation.topEnd,
                      color: AppColors.streak,
                      child: child!,
                    )
                  : child!,
              home: _home(),
            );
          },
        ),
      ),
    ),
  );

  Widget _home() {
    if (!state.loaded || !accounts.loaded) return const Scaffold();
    final account = accounts.account;
    if (account == null) {
      if (accounts.pending case final r?) return WaitingScreen(request: r);
      // The phone is the student's: set one up, or open theirs.
      if (state.profiles.isEmpty) return const OnboardingScreen();
    } else if (account.role == Role.teacher) {
      return const TeacherShell();
    } else if (account.role == Role.parent && accounts.adultMode) {
      return const ParentShell();
    }
    return state.current == null
        ? const ProfilePickerScreen()
        : const HomeShell();
  }
}
