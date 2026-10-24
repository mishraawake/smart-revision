import 'package:flutter/material.dart';

import 'app.dart';
import 'data/deck_repository.dart';
import 'data/firebase_account_service.dart';
import 'data/profile_store.dart';
import 'data/speaker.dart';
import 'firebase/environment.dart';
import 'models/account.dart';
import 'state/account_state.dart';
import 'state/progress_sync.dart';
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
  final progress = ProgressSync(app: state, accounts: accounts);
  state.onSessionEnd = progress.afterSession;

  // Whoever starts studying: their progress from other phones, and
  // teachers' work.
  String? studying;
  state.addListener(() {
    final p = state.current;
    if (p?.id == studying) return;
    studying = p?.id;
    if (p == null) return;
    progress.sync(p);
    accounts.loadAssignments(p.id);
  });

  // Coming back to the app picks up what changed meanwhile.
  AppLifecycleListener(
    onResume: () {
      accounts.refresh();
      if (state.current case final p?) progress.sync(p);
    },
  );

  state.load().then(
    (_) => accounts.load(hasProfiles: state.profiles.isNotEmpty),
  );
  runApp(SmartRevisionApp(state: state, accounts: accounts, speaker: speaker));
}
