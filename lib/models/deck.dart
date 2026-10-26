/// NCERT content for one class: subjects → chapters → flashcards.
class ClassDeck {
  ClassDeck({required this.classLevel, required this.subjects});

  factory ClassDeck.fromJson(Map<String, dynamic> json) => ClassDeck(
    classLevel: json['classLevel'] as int,
    subjects: [
      for (final s in json['subjects'] as List)
        Subject.fromJson(s as Map<String, dynamic>),
    ],
  );

  final int classLevel;
  final List<Subject> subjects;

  Iterable<Chapter> get chapters => subjects.expand((s) => s.chapters);

  Iterable<Flashcard> get allCards => chapters.expand((c) => c.cards);
}

class Subject {
  Subject({
    required this.id,
    required this.name,
    required this.chapters,
    this.colour,
    this.ink,
    this.glyph,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return Subject(
      id: id,
      name: json['name'] as String,
      colour: _hex(json['colour'] as String?),
      ink: _hex(json['ink'] as String?),
      glyph: json['glyph'] as String?,
      chapters: [
        for (final c in json['chapters'] as List)
          Chapter.fromJson(c as Map<String, dynamic>, subjectId: id),
      ],
    );
  }

  /// "#1E40AF" → 0xFF1E40AF.
  static int? _hex(String? s) =>
      s == null ? null : 0xFF000000 | int.parse(s.substring(1), radix: 16);

  final String id;
  final String name;
  final List<Chapter> chapters;

  /// Badge background and text colours (ARGB) and badge text, from the
  /// content sheet. Null keeps the app's built-in look for the subject.
  final int? colour;
  final int? ink;
  final String? glyph;

  Iterable<Flashcard> get cards => chapters.expand((c) => c.cards);
}

class Chapter {
  Chapter({
    required this.id,
    required this.subjectId,
    required this.number,
    required this.title,
    required this.cards,
    this.pairs = const [],
  });

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    required String subjectId,
  }) {
    final id = json['id'] as String;
    return Chapter(
      id: id,
      subjectId: subjectId,
      number: json['number'] as int,
      title: json['title'] as String,
      cards: [
        for (final c in json['cards'] as List)
          Flashcard.fromJson(
            c as Map<String, dynamic>,
            subjectId: subjectId,
            chapterId: id,
          ),
      ],
      pairs: [
        for (final p in (json['pairs'] as List?) ?? const [])
          MatchPair((p as List)[0] as String, p[1] as String),
      ],
    );
  }

  final String id;
  final String subjectId;
  final int number;
  final String title;
  final List<Flashcard> cards;

  /// Short pairs for "Match the pairs" questions, such as Yeast ↔ Bread.
  final List<MatchPair> pairs;
}

class MatchPair {
  const MatchPair(this.left, this.right);

  final String left;
  final String right;
}

/// A hand-written true-or-false sentence about a card.
class TrueFalse {
  const TrueFalse(this.text, this.answer);

  final String text;
  final bool answer;
}

/// A hand-written sentence with a gap, such as "Count in twos: two, four,
/// six, ___, ten." The gap is written as three underscores.
class Blank {
  const Blank(this.text, this.answer);

  final String text;
  final String answer;
}

class Flashcard {
  Flashcard({
    required this.id,
    required this.subjectId,
    required this.chapterId,
    required this.front,
    required this.back,
    this.hint,
    this.backWord,
    this.explain,
    this.source,
    this.wrong = const [],
    this.trueFalse,
    this.blank,
    this.level,
  });

  factory Flashcard.fromJson(
    Map<String, dynamic> json, {
    required String subjectId,
    required String chapterId,
  }) {
    final tf = json['tf'] as Map<String, dynamic>?;
    final blank = json['blank'] as Map<String, dynamic>?;
    return Flashcard(
      id: json['id'] as String,
      subjectId: subjectId,
      chapterId: chapterId,
      front: json['front'] as String,
      back: json['back'] as String,
      hint: json['hint'] as String?,
      backWord: json['backWord'] as String?,
      explain: json['explain'] as String?,
      source: json['source'] as String?,
      wrong: [...?(json['wrong'] as List?)?.cast<String>()],
      trueFalse: tf == null
          ? null
          : TrueFalse(tf['text'] as String, tf['answer'] as bool),
      blank: blank == null
          ? null
          : Blank(blank['text'] as String, blank['answer'] as String),
      level: json['level'] as int?,
    );
  }

  final String id;
  final String subjectId;
  final String chapterId;
  final String front;
  final String back;

  /// Nudge shown under the question ("Count in 2s: two, four…").
  final String? hint;

  /// Short gloss shown beside the answer ("six", "a bacterium").
  final String? backWord;
  final String? explain;
  final String? source;

  /// Hand-written wrong answers for quizzes. May be empty; the quiz fills
  /// in options from other cards.
  final List<String> wrong;

  final TrueFalse? trueFalse;
  final Blank? blank;

  /// How hard the card is: 1 basic, 2 intermediate, 3 advanced. Null when
  /// the sheet leaves it empty.
  final int? level;
}
