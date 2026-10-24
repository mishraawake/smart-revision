import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_revision/logic/levels.dart';
import 'package:smart_revision/logic/quiz.dart';
import 'package:smart_revision/models/deck.dart';

Flashcard card(
  String id,
  String back, {
  String chapter = 'ch1',
  String subject = 'maths',
  String? front,
  List<String> wrong = const [],
  TrueFalse? tf,
  Blank? blank,
}) => Flashcard(
  id: id,
  subjectId: subject,
  chapterId: chapter,
  front: front ?? 'Q $id',
  back: back,
  wrong: wrong,
  trueFalse: tf,
  blank: blank,
);

Chapter chapter(List<Flashcard> cards, {List<MatchPair> pairs = const []}) =>
    Chapter(
      id: 'ch1',
      subjectId: 'maths',
      number: 1,
      title: 'Ch',
      cards: cards,
      pairs: pairs,
    );

void main() {
  final rng = Random(7);

  group('multiple choice', () {
    test('hand-written wrong answers are used as-is', () {
      final c = card('a', '7', wrong: ['4']);
      final q = QuizBuilder.mcq(c, pool: [c], random: rng)!;
      expect(q.options, unorderedEquals(['7', '4']));
      expect(q.correct, '7');
    });

    test('numeric answers get nearby numbers', () {
      final c = card('a', '6');
      final q = QuizBuilder.mcq(c, pool: [c], random: rng)!;
      expect(q.options, hasLength(QuizBuilder.optionCount));
      expect(q.options.toSet(), hasLength(q.options.length));
      for (final o in q.options) {
        expect((int.parse(o) - 6).abs(), lessThanOrEqualTo(3));
      }
    });

    test('word answers borrow other answers, same chapter first', () {
      final target = card('a', 'Heart');
      final pool = [
        target,
        card('b', 'Lungs'),
        card('c', 'Brain'),
        card('d', 'Liver'),
        card('e', '42'),
        card('f', 'Kidney', chapter: 'ch2'),
      ];
      final q = QuizBuilder.mcq(target, pool: pool, random: rng)!;
      expect(q.options, unorderedEquals(['Heart', 'Lungs', 'Brain', 'Liver']));
    });

    test('duplicate options are dropped, ignoring case', () {
      final c = card('a', 'Sad', wrong: ['sad', 'Glad', 'GLAD']);
      final q = QuizBuilder.mcq(c, pool: [c], random: rng)!;
      expect(q.options, unorderedEquals(['Sad', 'Glad']));
    });

    test('a card with no possible wrong answer is skipped', () {
      final c = card('a', 'Only');
      expect(QuizBuilder.mcq(c, pool: [c], random: rng), isNull);
      expect(QuizBuilder.build([c], pool: [c], random: rng), isEmpty);
    });
  });

  group('true or false', () {
    test('uses the hand-written sentence when there is one', () {
      final c = card(
        'a',
        'Viruses',
        tf: const TrueFalse('Antibiotics cure flu.', false),
      );
      final q = QuizBuilder.trueFalse(c, pool: [c], random: rng)!;
      expect(q.statement, 'Antibiotics cure flu.');
      expect(q.claim, isNull);
      expect(q.isTrue, isFalse);
    });

    test('otherwise pairs the question with the right or a wrong answer', () {
      final c = card(
        'a',
        'Yeast',
        wrong: ['Rhizobium', 'Amoeba', 'Lactobacillus'],
      );
      final seen = <bool>{};
      for (var i = 0; i < 20; i++) {
        final q = QuizBuilder.trueFalse(c, pool: [c], random: Random(i))!;
        expect(q.statement, c.front);
        expect(q.claim == 'Yeast', q.isTrue);
        seen.add(q.isTrue);
      }
      expect(seen, {true, false});
    });

    test('yes/no cards are not turned into true/false', () {
      final c = card('a', 'No', wrong: ['Yes']);
      expect(QuizBuilder.trueFalse(c, pool: [c], random: rng), isNull);
    });
  });

  group('fill the blank', () {
    test('Junior gets word tiles including the answer', () {
      final c = card(
        'a',
        'eight',
        wrong: ['seven', 'nine', 'twelve'],
        blank: const Blank('Count in twos: two, four, six, ___, ten.', 'eight'),
      );
      final q = QuizBuilder.fillBlank(c, junior: true, pool: [c], random: rng)!;
      expect(q.typed, isFalse);
      expect(q.tiles, unorderedEquals(['eight', 'seven', 'nine', 'twelve']));
      expect(q.parts, ('Count in twos: two, four, six, ', ', ten.'));
    });

    test('Senior types short answers only', () {
      final short = card('a', 'Rhizobium');
      final long = card(
        'b',
        'Manure is organic; fertilisers are man-made salts',
      );
      expect(
        QuizBuilder.fillBlank(
          short,
          junior: false,
          pool: [short],
          random: rng,
        )!.typed,
        isTrue,
      );
      expect(
        QuizBuilder.fillBlank(long, junior: false, pool: [long], random: rng),
        isNull,
      );
    });

    test('typed answers ignore case, punctuation and articles', () {
      expect(
        TypedAnswer.check('  rhizobium. ', 'Rhizobium'),
        TypedResult.correct,
      );
      expect(
        TypedAnswer.check('the Bastille', 'The Bastille'),
        TypedResult.correct,
      );
      expect(
        TypedAnswer.check('a bastille', 'The Bastille'),
        TypedResult.correct,
      );
    });

    test('small spelling slips are close; others are wrong', () {
      expect(TypedAnswer.check('Rhizobiom', 'Rhizobium'), TypedResult.close);
      expect(
        TypedAnswer.check('fermentaion', 'Fermentation'),
        TypedResult.close,
      );
      expect(TypedAnswer.check('Yeest', 'Yeast'), TypedResult.close);
      expect(TypedAnswer.check('Yeast', 'Rhizobium'), TypedResult.wrong);
      // Very short answers must be exact: 'sad' is not 'mad'.
      expect(TypedAnswer.check('mad', 'sad'), TypedResult.wrong);
      expect(TypedAnswer.check('', 'sad'), TypedResult.wrong);
    });
  });

  group('match the pairs', () {
    test('uses hand-written pairs, with the right column shuffled', () {
      final ch = chapter(
        [],
        pairs: const [
          MatchPair('Yeast', 'Bread'),
          MatchPair('Lactobacillus', 'Curd'),
          MatchPair('Rhizobium', 'Nitrogen fixation'),
          MatchPair('Plasmodium', 'Malaria'),
        ],
      );
      final q = QuizBuilder.matchQuestion([ch], size: 4, random: rng)!;
      expect(q.pairs, hasLength(4));
      expect(q.rightOrder.toSet(), {0, 1, 2, 3});
    });

    test('falls back to short cards, and needs enough unique pairs', () {
      final cards = [
        card('a', '6', front: '3 + 3'),
        card('b', '8', front: '4 + 4'),
        card('c', '10', front: '5 + 5'),
      ];
      expect(
        QuizBuilder.matchQuestion([chapter(cards)], size: 3, random: rng),
        isNotNull,
      );
      expect(
        QuizBuilder.matchQuestion([chapter(cards)], size: 4, random: rng),
        isNull,
      );
    });
  });

  test('a quiz mixes types and puts one match question fifth', () {
    final cards = [
      for (var i = 0; i < 12; i++)
        card('c$i', 'Answer $i', wrong: ['W1 $i', 'W2 $i', 'W3 $i']),
    ];
    final ch = chapter(
      cards,
      pairs: const [
        MatchPair('A', '1'),
        MatchPair('B', '2'),
        MatchPair('C', '3'),
        MatchPair('D', '4'),
      ],
    );
    final qs = QuizBuilder.build(
      cards,
      pool: cards,
      chapters: [ch],
      count: 10,
      random: rng,
    );
    expect(qs, hasLength(10));
    expect(qs[4], isA<MatchQuestion>());
    expect(qs.whereType<MatchQuestion>(), hasLength(1));
    expect(qs.whereType<McqQuestion>(), isNotEmpty);
    expect(qs.whereType<TrueFalseQuestion>(), isNotEmpty);
    expect(qs.whereType<FillBlankQuestion>(), isNotEmpty);
  });

  test('a session scores answers and lists missed cards', () {
    final cards = [for (var i = 1; i <= 3; i++) card('c$i', '${i * 10}')];
    final qs = [
      for (final c in cards) QuizBuilder.mcq(c, pool: cards, random: rng)!,
    ];
    final session = QuizSession(qs);

    expect(session.answer(qs[0].correctIndex), isTrue);
    expect(
      session.answer((qs[1].correctIndex + 1) % qs[1].options.length),
      isFalse,
    );
    session.answer(qs[2].correctIndex);

    expect(session.finished, isTrue);
    expect(session.score, 2);
    expect(session.missed, [cards[1]]);
    expect(() => session.answer(0), throwsStateError);
  });

  group('levels and stars', () {
    test('quiz stars: 90% for three, 70% for two, 50% for one', () {
      expect(quizStars(5, 5), 3);
      expect(quizStars(4, 5), 2);
      expect(quizStars(3, 5), 1);
      expect(quizStars(2, 5), 0);
      expect(quizStars(9, 10), 3);
      expect(quizStars(8, 10), 2);
      expect(scoreForStars(3, 5), 5);
      expect(scoreForStars(3, 10), 9);
      expect(scoreForStars(2, 5), 4);
    });

    test('level n takes 50 × n XP', () {
      expect(Level.of(0).number, 1);
      expect(Level.of(49).number, 1);
      expect(Level.of(50).number, 2);
      final l4 = Level.of(320);
      expect(l4.number, 4);
      expect(l4.start, 300);
      expect(l4.next, 500);
      expect(l4.name, 'Super Learner');
    });
  });
}
