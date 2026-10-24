import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/deck.dart';
import '../theme/tokens.dart';

/// Loads NCERT decks. Phase 1 ships decks inside the app, so every chapter is
/// available offline; downloading decks from a server comes later.
class DeckRepository {
  DeckRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _cache = <int, ClassDeck?>{};

  /// Returns null when there is no content for [classLevel] yet.
  Future<ClassDeck?> load(int classLevel) async {
    if (_cache.containsKey(classLevel)) return _cache[classLevel];
    ClassDeck? deck;
    try {
      final raw = await _bundle.loadString(
        'assets/decks/class_$classLevel.json',
      );
      deck = ClassDeck.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      deck.subjects.forEach(SubjectStyle.useDeck);
    } on FlutterError {
      deck = null; // Asset not bundled for this class.
    }
    return _cache[classLevel] = deck;
  }
}
