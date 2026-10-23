import 'package:flutter/material.dart';

import 'data/speaker.dart';
import 'screens/home_shell.dart';
import 'screens/profile_picker_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

class SmartRevisionApp extends StatelessWidget {
  const SmartRevisionApp({
    super.key,
    required this.state,
    required this.speaker,
  });

  final AppState state;
  final Speaker speaker;

  @override
  Widget build(BuildContext context) => SpeakerScope(
    speaker: speaker,
    child: AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final junior = state.current?.isJunior ?? state.lastWasJunior;
          return MaterialApp(
            title: 'RevUp',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(junior ? Tier.junior : Tier.senior),
            home: !state.loaded
                ? const Scaffold()
                : state.current == null
                ? const ProfilePickerScreen()
                : const HomeShell(),
          );
        },
      ),
    ),
  );
}
