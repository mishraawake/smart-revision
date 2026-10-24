import 'package:flutter/material.dart';

import 'app.dart';
import 'data/account_service.dart';
import 'data/deck_repository.dart';
import 'data/profile_store.dart';
import 'data/speaker.dart';
import 'state/account_state.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final decks = DeckRepository();
  final speaker = TtsSpeaker();
  final state = AppState(decks: decks, store: ProfileStore());
  final accounts = AccountState(
    service: DemoAccountService(decks: decks),
    speaker: speaker,
  );
  state.load().then(
    (_) => accounts.load(hasProfiles: state.profiles.isNotEmpty),
  );
  runApp(SmartRevisionApp(state: state, accounts: accounts, speaker: speaker));
}
