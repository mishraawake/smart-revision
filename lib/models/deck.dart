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

  Iterable<Flashcard> get allCards =>
      subjects.expand((s) => s.chapters).expand((c) => c.cards);
}

class Subject {
  Subject({required this.id, required this.name, required this.chapters});

  factory Subject.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return Subject(
      id: id,
      name: json['name'] as String,
      chapters: [
        for (final c in json['chapters'] as List)
          Chapter.fromJson(c as Map<String, dynamic>, subjectId: id),
      ],
    );
  }

  final String id;
  final String name;
  final List<Chapter> chapters;

  Iterable<Flashcard> get cards => chapters.expand((c) => c.cards);
}

class Chapter {
  Chapter({
    required this.id,
    required this.subjectId,
    required this.number,
    required this.title,
    required this.cards,
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
    );
  }

  final String id;
  final String subjectId;
  final int number;
  final String title;
  final List<Flashcard> cards;
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
  });

  factory Flashcard.fromJson(
    Map<String, dynamic> json, {
    required String subjectId,
    required String chapterId,
  }) => Flashcard(
    id: json['id'] as String,
    subjectId: subjectId,
    chapterId: chapterId,
    front: json['front'] as String,
    back: json['back'] as String,
    hint: json['hint'] as String?,
    backWord: json['backWord'] as String?,
    explain: json['explain'] as String?,
    source: json['source'] as String?,
  );

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
}
