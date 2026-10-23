import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_revision/logic/quiz.dart';
import 'package:smart_revision/models/deck.dart';

Flashcard card(
  String id,
  String back, {
  String chapter = 'ch1',
  String subject = 'maths',
  List<String> wrong = const [],
}) => Flashcard(
  id: id,
  subjectId: subject,
  chapterId: chapter,
  front: 'Q $id',
  back: back,
  wrong: wrong,
);

void main() {
  final rng = Random(7);

  test('hand-written wrong answers are used as-is', () {
    final c = card('a', '7', wrong: ['4']);
    final q = QuizBuilder.question(c, pool: [c], random: rng)!;
    expect(q.options, unorderedEquals(['7', '4']));
    expect(q.correct, '7');
  });

  test(
    'numeric answers get nearby numbers when no wrong answers are given',
    () {
      final c = card('a', '6');
      final q = QuizBuilder.question(c, pool: [c], random: rng)!;
      expect(q.options, hasLength(QuizBuilder.optionCount));
      expect(q.options.toSet(), hasLength(q.options.length));
      expect(q.options.where((o) => o == '6'), hasLength(1));
      for (final o in q.options) {
        expect((int.parse(o) - 6).abs(), lessThanOrEqualTo(3));
      }
    },
  );

  test(
    'word answers borrow other answers, same chapter first, never numbers',
    () {
      final target = card('a', 'Heart');
      final pool = [
        target,
        card('b', 'Lungs'),
        card('c', 'Brain'),
        card('d', 'Liver'),
        card('e', '42'),
        card('f', 'Kidney', chapter: 'ch2'),
      ];
      final q = QuizBuilder.question(target, pool: pool, random: rng)!;
      expect(q.options, unorderedEquals(['Heart', 'Lungs', 'Brain', 'Liver']));
    },
  );

  test('duplicate options are dropped, ignoring case', () {
    final c = card('a', 'Sad', wrong: ['sad', 'Glad', 'GLAD']);
    final q = QuizBuilder.question(c, pool: [c], random: rng)!;
    expect(q.options, unorderedEquals(['Sad', 'Glad']));
  });

  test('a card with no possible wrong answer is skipped', () {
    final c = card('a', 'Only');
    expect(QuizBuilder.question(c, pool: [c], random: rng), isNull);
    expect(QuizBuilder.build([c], pool: [c], random: rng), isEmpty);
  });

  test('build caps the number of questions', () {
    final cards = [for (var i = 0; i < 15; i++) card('c$i', '$i')];
    expect(
      QuizBuilder.build(cards, pool: cards, count: 10, random: rng),
      hasLength(10),
    );
  });

  test('a session scores answers and lists missed cards', () {
    final cards = [for (var i = 1; i <= 3; i++) card('c$i', '${i * 10}')];
    final session = QuizSession(
      QuizBuilder.build(cards, pool: cards, random: rng),
    );

    expect(session.answer(session.current.correctIndex), isTrue);
    final wrongIndex =
        (session.current.correctIndex + 1) % session.current.options.length;
    final missedCard = session.current.card;
    expect(session.answer(wrongIndex), isFalse);
    session.answer(session.current.correctIndex);

    expect(session.finished, isTrue);
    expect(session.score, 2);
    expect(session.missed, [missedCard]);
    expect(() => session.answer(0), throwsStateError);
  });
}
