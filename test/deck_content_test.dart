import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_revision/data/deck_repository.dart';
import 'package:smart_revision/logic/quiz.dart';
import 'package:smart_revision/models/deck.dart';
import 'package:smart_revision/theme/tokens.dart';

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

  test('every card can be asked as a multiple-choice question', () {
    final rng = Random(1);
    for (final deck in decks.values) {
      final pool = deck.allCards.toList();
      for (final c in pool) {
        final q = QuizBuilder.mcq(c, pool: pool, random: rng);
        expect(q, isNotNull, reason: '${c.id} has no wrong options');
        expect(q!.correct, c.back);
      }
    }
  });

  test('every chapter has usable match pairs and makes a full quiz', () {
    final rng = Random(2);
    for (final deck in decks.values) {
      final junior = deck.classLevel <= 5;
      for (final ch in deck.chapters) {
        final lefts = ch.pairs.map((p) => p.left.toLowerCase()).toSet();
        final rights = ch.pairs.map((p) => p.right.toLowerCase()).toSet();
        expect(ch.pairs.length, greaterThanOrEqualTo(4), reason: ch.id);
        expect(lefts, hasLength(ch.pairs.length), reason: ch.id);
        expect(rights, hasLength(ch.pairs.length), reason: ch.id);

        final qs = QuizBuilder.build(
          ch.cards,
          pool: deck.allCards,
          chapters: [ch],
          count: 5,
          junior: junior,
          random: rng,
        );
        expect(qs, hasLength(5), reason: ch.id);
        expect(qs.whereType<MatchQuestion>(), hasLength(1), reason: ch.id);
      }
    }
  });

  test('hand-written blanks contain exactly one gap', () {
    for (final c in decks.values.expand((d) => d.allCards)) {
      if (c.blank case final b?) {
        expect('___'.allMatches(b.text), hasLength(1), reason: c.id);
      }
    }
  });

  test('subject colours and badges come from the deck', () {
    final science = decks[8]!.subjects.firstWhere((s) => s.id == 'science');
    expect(science.colour, 0xFFCFFAFE);
    expect(science.ink, 0xFF155E75);
    expect(science.glyph, 'Sc');

    SubjectStyle.useDeck(
      Subject(id: 'hindi', name: 'Hindi', chapters: [], colour: 0xFFFFE4E6),
    );
    final hindi = SubjectStyle.of('hindi');
    expect(hindi.background, const Color(0xFFFFE4E6));
    expect(hindi.glyph, '•', reason: 'parts the sheet leaves empty fall back');
  });
}
