import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_revision/data/deck_repository.dart';
import 'package:smart_revision/logic/quiz.dart';
import 'package:smart_revision/models/deck.dart';

/// Checks every bundled deck, so a typo in the JSON fails the build instead
/// of breaking a student's session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedSubjects = {
    1: {'maths', 'english'},
    2: {'maths', 'english'},
    3: {'maths', 'english', 'evs'},
    4: {'maths', 'english', 'evs'},
    5: {'maths', 'english', 'evs'},
    6: {'maths', 'science', 'social', 'english'},
    7: {'maths', 'science', 'social', 'english'},
    8: {'maths', 'science', 'social', 'english'},
    9: {'maths', 'science', 'social', 'english'},
    10: {'maths', 'science', 'social', 'english'},
  };

  late Map<int, ClassDeck> decks;

  setUpAll(() async {
    final repo = DeckRepository();
    decks = {
      for (final level in expectedSubjects.keys)
        level: (await repo.load(level))!,
    };
  });

  test('every class has a deck with its core subjects', () {
    for (final MapEntry(key: level, value: subjects)
        in expectedSubjects.entries) {
      final deck = decks[level]!;
      expect(deck.classLevel, level);
      expect(
        deck.subjects.map((s) => s.id).toSet(),
        subjects,
        reason: 'Class $level',
      );
      for (final s in deck.subjects) {
        expect(s.cards, isNotEmpty, reason: 'Class $level ${s.name}');
      }
    }
  });

  test('card and chapter ids are unique across all classes', () {
    final cardIds = <String>{};
    final chapterIds = <String>{};
    for (final deck in decks.values) {
      for (final ch in deck.subjects.expand((s) => s.chapters)) {
        expect(
          chapterIds.add(ch.id),
          isTrue,
          reason: 'duplicate chapter ${ch.id}',
        );
      }
      for (final c in deck.allCards) {
        expect(cardIds.add(c.id), isTrue, reason: 'duplicate card ${c.id}');
      }
    }
  });

  test('wrong answers never repeat or equal the right answer', () {
    for (final c in decks.values.expand((d) => d.allCards)) {
      final norm = [c.back, ...c.wrong].map((s) => s.trim().toLowerCase());
      expect(norm.toSet(), hasLength(norm.length), reason: c.id);
    }
  });

  test('every card can be asked as a quiz question', () {
    final rng = Random(1);
    for (final deck in decks.values) {
      final pool = deck.allCards.toList();
      for (final c in pool) {
        final q = QuizBuilder.question(c, pool: pool, random: rng);
        expect(q, isNotNull, reason: '${c.id} has no wrong options');
        expect(q!.options.length, greaterThanOrEqualTo(2), reason: c.id);
        expect(q.correct, c.back);
      }
    }
  });
}
