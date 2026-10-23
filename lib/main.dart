import 'package:flutter/material.dart';

import 'app.dart';
import 'data/deck_repository.dart';
import 'data/profile_store.dart';
import 'data/speaker.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(decks: DeckRepository(), store: ProfileStore())
    ..load();
  runApp(SmartRevisionApp(state: state, speaker: TtsSpeaker()));
}
