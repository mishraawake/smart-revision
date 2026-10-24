import 'package:flutter/material.dart';

import 'app.dart';
import 'data/deck_repository.dart';
import 'data/firebase_account_service.dart';
import 'data/profile_store.dart';
import 'data/speaker.dart';
import 'firebase/environment.dart';
import 'models/account.dart';
import 'state/account_state.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Environment.init();
  final decks = DeckRepository();
  final speaker = TtsSpeaker();
  final state = AppState(decks: decks, store: ProfileStore());
  final accounts = AccountState(
    service: FirebaseAccountService(),
    speaker: speaker,
  );

  // A child added on this phone is saved to the parent's account.
  state.onProfileAdded = (p) => accounts.saveChild(
    ChildRecord(
      id: p.id,
      name: p.name,
      classLevel: p.classLevel,
      avatar: p.avatar,
    ),
  );
  // Teachers' work for whoever is studying now.
  String? studying;
  state.addListener(() {
    final id = state.current?.id;
    if (id == studying) return;
    studying = id;
    if (id != null) accounts.loadAssignments(id);
  });

  // Coming back to the app picks up what changed meanwhile.
  AppLifecycleListener(onResume: accounts.refresh);

  state.load().then(
    (_) => accounts.load(hasProfiles: state.profiles.isNotEmpty),
  );
  runApp(SmartRevisionApp(state: state, accounts: accounts, speaker: speaker));
}
