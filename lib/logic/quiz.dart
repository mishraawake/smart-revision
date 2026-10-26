import 'dart:math';

import '../models/deck.dart';

/// A quiz question. Every type except [MatchQuestion] is about one card.
sealed class QuizQuestion {
  const QuizQuestion();

  /// The card this question tests, if any; wrong answers send it back to
  /// the review deck.
  Flashcard? get card;
}

class McqQuestion extends QuizQuestion {
  McqQuestion({
    required this.card,
    required this.options,
    required this.correctIndex,
  });

  @override
  final Flashcard card;
  final List<String> options;
  final int correctIndex;

  String get correct => options[correctIndex];
}

class TrueFalseQuestion extends QuizQuestion {
  TrueFalseQuestion({
    required this.card,
    required this.statement,
    required this.isTrue,
    this.claim,
  });

  @override
  final Flashcard card;

  /// The sentence to judge, or the card's question when [claim] is set.
  final String statement;

  /// A proposed answer to [statement], for cards without a hand-written
  /// sentence: "Which microbe makes bread rise?" + "Answer: Yeast".
  final String? claim;
  final bool isTrue;
}

class FillBlankQuestion extends QuizQuestion {
  FillBlankQuestion({
    required this.card,
    required this.answer,
    required this.tiles,
    required this.typed,
    this.sentence,
  });

  @override
  final Flashcard card;

  /// Text with a `___` gap. Null means: show the card's question and a gap.
  final String? sentence;
  final String answer;

  /// Word tiles to pick from (Junior). Includes [answer].
  final List<String> tiles;

  /// Senior types the answer instead of picking a tile.
  final bool typed;

  /// [sentence] split around the gap.
  (String before, String after) get parts {
    final s = sentence ?? '';
    final i = s.indexOf('___');
    return i < 0 ? (s, '') : (s.substring(0, i), s.substring(i + 3));
  }

  TypedResult check(String given) => TypedAnswer.check(given, answer);
}

class MatchQuestion extends QuizQuestion {
  MatchQuestion({required this.pairs, required this.rightOrder});

  @override
  Flashcard? get card => null;

  final List<MatchPair> pairs;

  /// Indexes into [pairs], giving the shuffled order of the right column.
  final List<int> rightOrder;

  /// Up to this many wrong taps still count as a right answer.
  static const allowedSlips = 1;
}

enum TypedResult { correct, close, wrong }

abstract final class TypedAnswer {
  /// Capitals, spaces, punctuation and a leading "a"/"an"/"the" don't
  /// matter; one or two slipped letters (by length) count as "close".
  static TypedResult check(String given, String answer) {
    final g = _norm(given);
    final a = _norm(answer);
    if (g.isEmpty) return TypedResult.wrong;
    if (g == a) return TypedResult.correct;
    final allowed = a.length <= 4 ? 0 : (a.length <= 8 ? 1 : 2);
    return _distance(g, a) <= allowed ? TypedResult.close : TypedResult.wrong;
  }

  /// Short, single-idea answers are fair to type; sentences are not.
  static bool suits(String answer) =>
      answer.length <= 24 && answer.trim().split(RegExp(r'\s+')).length <= 3;

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'^(a|an|the)\s+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Edit distance where swapping two neighbouring letters ("eigth") is
  /// one slip, not two.
  static int _distance(String a, String b) {
    final d = List.generate(
      a.length + 1,
      (i) => List<int>.generate(b.length + 1, (j) => i == 0 ? j : 0)..[0] = i,
    );
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce(min);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
        }
      }
    }
    return d[a.length][b.length];
  }
}

/// How a question was answered.
class QuizAnswer {
  const QuizAnswer(
    this.question, {
    required this.correct,
    this.given,
    this.close = false,
    this.hintUsed = false,
    this.slips = 0,
    this.timedOut = false,
  });

  final QuizQuestion question;
  final bool correct;

  /// What the student chose or typed, for "You said …". Null when skipped
  /// or timed out.
  final String? given;

  /// A typed answer with a small spelling slip; still counts as correct.
  final bool close;
  final bool hintUsed;

  /// Wrong taps in a match question.
  final int slips;

  /// The timer ran out in timed mode; [given] is null.
  final bool timedOut;
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
  int get total => questions.length;

  List<QuizAnswer> get mistakes => [
    for (final a in answers)
      if (!a.correct) a,
  ];

  /// Cards behind wrong answers, for the review deck.
  List<Flashcard> get missed => [for (final a in mistakes) ?a.question.card];

  void record(QuizAnswer a) {
    if (finished) throw StateError('Quiz is already finished');
    if (!identical(a.question, current)) {
      throw ArgumentError('Answer is not for the current question');
    }
    answers.add(a);
  }

  /// Convenience for multiple choice; returns whether it was right.
  bool answer(int chosenIndex) {
    if (finished) throw StateError('Quiz is already finished');
    final q = current as McqQuestion;
    RangeError.checkValidIndex(chosenIndex, q.options);
    final a = QuizAnswer(
      q,
      correct: chosenIndex == q.correctIndex,
      given: q.options[chosenIndex],
    );
    record(a);
    return a.correct;
  }
}

/// How hard a quiz is. Each level asks its own cards first and borrows from
/// the nearest level when a chapter runs short.
enum QuizLevel {
  basic('Basic', 1),
  intermediate('Intermediate', 2),
  advanced('Advanced', 3);

  const QuizLevel(this.label, this.cardLevel);
  final String label;
  final int cardLevel;

  /// [cards] shuffled, with this level's cards first, then the next nearest
  /// level. Cards with no level count as intermediate.
  List<Flashcard> order(Iterable<Flashcard> cards, Random random) {
    final shuffled = [...cards]..shuffle(random);
    int rank(Flashcard c) {
      final gap = ((c.level ?? 2) - cardLevel).abs();
      // On a tie, an advanced quiz borrows harder cards, the others easier.
      final harder = (c.level ?? 2) > cardLevel;
      return gap * 2 + (harder == (this == advanced) ? 0 : 1);
    }

    // List.sort is not stable, so ties fall back to the shuffled position.
    final keyed = [
      for (var i = 0; i < shuffled.length; i++) (i, rank(shuffled[i])),
    ];
    keyed.sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : a.$1 - b.$1);
    return [for (final (i, _) in keyed) shuffled[i]];
  }
}

abstract final class QuizBuilder {
  static const optionCount = 4;

  /// Builds up to [count] questions from [cards], mixing multiple choice,
  /// true/false and fill-the-blank, with one match question in quizzes of
  /// five or more when [chapters] offer pairs. With a [level], cards of
  /// that level are asked first.
  static List<QuizQuestion> build(
    List<Flashcard> cards, {
    required Iterable<Flashcard> pool,
    Iterable<Chapter> chapters = const [],
    int count = 10,
    bool junior = false,
    QuizLevel? level,
    Random? random,
  }) {
    final rng = random ?? Random();
    final poolList = pool.toList();
    final queue = level == null
        ? ([...cards]..shuffle(rng))
        : level.order(cards, rng);
    final matchAt = count >= 5 ? min(4, count - 1) : -1;
    final match = matchAt < 0
        ? null
        : matchQuestion(chapters, size: junior ? 3 : 4, random: rng);

    final out = <QuizQuestion>[];
    var turn = 0;
    while (out.length < count && (queue.isNotEmpty || match != null)) {
      if (out.length == matchAt && match != null && !out.contains(match)) {
        out.add(match);
        continue;
      }
      if (queue.isEmpty) break;
      final card = queue.removeAt(0);
      final q = switch (turn++ % 3) {
        1 => trueFalse(card, pool: poolList, random: rng),
        2 => fillBlank(card, junior: junior, pool: poolList, random: rng),
        _ => null,
      };
      final asked = q ?? mcq(card, pool: poolList, random: rng);
      if (asked != null) out.add(asked);
    }
    return out;
  }

  static McqQuestion? mcq(
    Flashcard card, {
    required List<Flashcard> pool,
    required Random random,
  }) {
    final wrong = wrongOptions(card, pool: pool, random: random);
    if (wrong.isEmpty) return null;
    final options = [card.back, ...wrong]..shuffle(random);
    return McqQuestion(
      card: card,
      options: options,
      correctIndex: options.indexOf(card.back),
    );
  }

  static TrueFalseQuestion? trueFalse(
    Flashcard card, {
    required List<Flashcard> pool,
    required Random random,
  }) {
    if (card.trueFalse case final tf?) {
      return TrueFalseQuestion(
        card: card,
        statement: tf.text,
        isTrue: tf.answer,
      );
    }
    final wrong = wrongOptions(card, pool: pool, random: random);
    // Two-option cards ("Yes"/"No") make a muddled true/false; ask them as
    // multiple choice instead.
    if (wrong.length < 2) return null;
    final isTrue = random.nextBool();
    return TrueFalseQuestion(
      card: card,
      statement: card.front,
      claim: isTrue ? card.back : wrong.first,
      isTrue: isTrue,
    );
  }

  static FillBlankQuestion? fillBlank(
    Flashcard card, {
    required bool junior,
    required List<Flashcard> pool,
    required Random random,
  }) {
    final answer = card.blank?.answer ?? card.back;
    if (!junior) {
      if (!TypedAnswer.suits(answer)) return null;
      return FillBlankQuestion(
        card: card,
        sentence: card.blank?.text,
        answer: answer,
        tiles: const [],
        typed: true,
      );
    }
    final wrong = answer == card.back
        ? wrongOptions(card, pool: pool, random: random)
        : _nearbyNumbers(answer, random).take(optionCount - 1).toList();
    if (wrong.length < 2) return null;
    return FillBlankQuestion(
      card: card,
      sentence: card.blank?.text,
      answer: answer,
      tiles: [answer, ...wrong]..shuffle(random),
      typed: false,
    );
  }

  /// [size] pairs from the chapters' hand-written pairs, or else from cards
  /// whose question and answer are both short.
  static MatchQuestion? matchQuestion(
    Iterable<Chapter> chapters, {
    required int size,
    required Random random,
  }) {
    var pairs = [for (final ch in chapters) ...ch.pairs];
    if (pairs.length < size) {
      pairs = [
        for (final c in chapters.expand((ch) => ch.cards))
          if (c.front.length <= 32 && c.back.length <= 20)
            MatchPair(c.front, c.back),
      ];
    }
    // Both sides must be unique or a tap could match two ways.
    final seen = <String>{};
    pairs = [
      for (final p in pairs..shuffle(random))
        if (seen.add('L${p.left.toLowerCase()}') &&
            seen.add('R${p.right.toLowerCase()}'))
          p,
    ];
    if (pairs.length < size) return null;
    final picked = pairs.take(size).toList();
    return MatchQuestion(
      pairs: picked,
      rightOrder: [for (var i = 0; i < size; i++) i]..shuffle(random),
    );
  }

  /// A card's own `wrong` list is used as-is when present. Otherwise wrong
  /// options are nearby numbers for numeric answers, then answers of other
  /// cards in [pool] (same chapter before same subject).
  static List<String> wrongOptions(
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
      for (final w in [...card.wrong]..shuffle(random)) {
        offer(w);
      }
      return wrong;
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
    return wrong;
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
    return [
      for (final s in steps)
        if (n < 0 || n + s >= 0) '${n + s}',
    ]..shuffle(random);
  }
}
