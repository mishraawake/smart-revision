import 'dart:math';

import '../models/deck.dart';

/// One multiple-choice question built from a flashcard.
class QuizQuestion {
  QuizQuestion({
    required this.card,
    required this.options,
    required this.correctIndex,
  });

  final Flashcard card;
  final List<String> options;
  final int correctIndex;

  String get correct => options[correctIndex];
}

class QuizAnswer {
  const QuizAnswer(this.question, this.chosenIndex);

  final QuizQuestion question;
  final int chosenIndex;

  bool get correct => chosenIndex == question.correctIndex;
}

/// Runs a quiz: one question at a time, scored as it goes.
class QuizSession {
  QuizSession(this.questions);

  final List<QuizQuestion> questions;
  final answers = <QuizAnswer>[];

  int get index => answers.length;
  bool get finished => index >= questions.length;
  QuizQuestion get current => questions[index];
  int get score => answers.where((a) => a.correct).length;
  List<Flashcard> get missed => [
    for (final a in answers)
      if (!a.correct) a.question.card,
  ];

  /// Records the choice for the current question and returns whether it was
  /// right.
  bool answer(int chosenIndex) {
    if (finished) throw StateError('Quiz is already finished');
    RangeError.checkValidIndex(chosenIndex, current.options);
    final a = QuizAnswer(current, chosenIndex);
    answers.add(a);
    return a.correct;
  }
}

abstract final class QuizBuilder {
  static const optionCount = 4;

  /// Builds up to [count] questions from [cards]. A card's own `wrong` list
  /// is used as-is when present. Otherwise wrong options are nearby numbers
  /// for numeric answers, then answers of other cards in [pool] (same
  /// chapter before same subject). Cards that cannot get at least one wrong
  /// option are skipped.
  static List<QuizQuestion> build(
    List<Flashcard> cards, {
    required Iterable<Flashcard> pool,
    int count = 10,
    Random? random,
  }) {
    final rng = random ?? Random();
    final poolList = pool.toList();
    final picked = [...cards]..shuffle(rng);
    final out = <QuizQuestion>[];
    for (final card in picked) {
      if (out.length >= count) break;
      final q = question(card, pool: poolList, random: rng);
      if (q != null) out.add(q);
    }
    return out;
  }

  static QuizQuestion? question(
    Flashcard card, {
    required List<Flashcard> pool,
    required Random random,
  }) {
    final wrong = <String>[];
    final seen = {_norm(card.back)};

    void offer(String option) {
      if (wrong.length >= optionCount - 1) return;
      if (seen.add(_norm(option))) wrong.add(option);
    }

    // Hand-written options are authoritative: padding "Which is more: 7 or
    // 4?" with 6 and 8 would make a nonsense question.
    if (card.wrong.isNotEmpty) {
      for (final w in card.wrong) {
        offer(w);
      }
      return wrong.isEmpty ? null : _shuffled(card, wrong, random);
    }
    for (final n in _nearbyNumbers(card.back, random)) {
      offer(n);
    }
    final others = [
      ...(pool.where((c) => c.chapterId == card.chapterId).toList()
        ..shuffle(random)),
      ...(pool
          .where(
            (c) =>
                c.subjectId == card.subjectId && c.chapterId != card.chapterId,
          )
          .toList()
        ..shuffle(random)),
    ];
    for (final c in others) {
      if (c.id != card.id && _sameKind(c.back, card.back)) offer(c.back);
    }
    return wrong.isEmpty ? null : _shuffled(card, wrong, random);
  }

  static QuizQuestion _shuffled(
    Flashcard card,
    List<String> wrong,
    Random random,
  ) {
    final options = [card.back, ...wrong]..shuffle(random);
    return QuizQuestion(
      card: card,
      options: options,
      correctIndex: options.indexOf(card.back),
    );
  }

  static String _norm(String s) => s.trim().toLowerCase();

  static final _int = RegExp(r'^-?\d+$');

  /// Numbers stand in for numbers and words for words, so a numeric answer
  /// is never padded with sentences.
  static bool _sameKind(String a, String b) =>
      _int.hasMatch(a.trim()) == _int.hasMatch(b.trim());

  static List<String> _nearbyNumbers(String answer, Random random) {
    if (!_int.hasMatch(answer.trim())) return const [];
    final n = int.parse(answer.trim());
    final steps = n.abs() >= 20 ? [10, -10, 1, -1, 2] : [1, -1, 2, -2, 3];
    final out = [
      for (final s in steps)
        if (n >= 0 ? n + s >= 0 : true) '${n + s}',
    ]..shuffle(random);
    return out;
  }
}
