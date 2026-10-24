import '../logic/scheduler.dart';

/// One finished quiz, kept for history, best scores and badges.
class QuizRecord {
  QuizRecord({
    required this.subjectId,
    required this.chapterId,
    required this.at,
    required this.score,
    required this.total,
    required this.seconds,
  });

  factory QuizRecord.fromJson(Map<String, dynamic> j) => QuizRecord(
    subjectId: j['subjectId'] as String?,
    chapterId: j['chapterId'] as String?,
    at: DateTime.parse(j['at'] as String),
    score: j['score'] as int,
    total: j['total'] as int,
    seconds: j['seconds'] as int,
  );

  /// Null for a mixed quiz across subjects.
  final String? subjectId;

  /// Null for a mixed quiz.
  final String? chapterId;
  final DateTime at;
  final int score;
  final int total;
  final int seconds;

  double get accuracy => total == 0 ? 0 : score / total;

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'chapterId': chapterId,
    'at': at.toIso8601String(),
    'score': score,
    'total': total,
    'seconds': seconds,
  };
}

/// A school test the student is preparing for.
class Exam {
  Exam({
    required this.id,
    required this.subjectId,
    required this.day,
    required this.chapterIds,
  });

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
    id: j['id'] as String,
    subjectId: j['subjectId'] as String,
    day: j['day'] as String,
    chapterIds: (j['chapterIds'] as List).cast<String>(),
  );

  final String id;
  final String subjectId;

  /// yyyy-mm-dd.
  final String day;
  final List<String> chapterIds;

  DateTime get date => DateTime.parse(day);

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'day': day,
    'chapterIds': chapterIds,
  };
}

/// One student on this phone. No passwords; everything stays on the device.
class Profile {
  Profile({
    required this.id,
    required this.name,
    required this.classLevel,
    required this.avatar,
    this.stars = 0,
    this.xp = 0,
    this.streak = 0,
    this.lastStudyDay,
    Set<String>? studyDays,
    Map<String, int>? activity,
    Map<String, int>? seconds,
    Map<String, CardState>? cards,
    Map<String, String>? badges,
    Set<String>? events,
    List<QuizRecord>? quizzes,
    this.goalDay,
    this.goalDone = 0,
    this.lastSubjectId,
    this.lastChapterId,
    this.lastStudiedAt,
    this.goalCards,
    Set<String>? covered,
    List<Exam>? exams,
    this.owlColor = 'purple',
    this.owlHat = 'none',
  }) : covered = covered ?? {},
       exams = exams ?? [],
       studyDays = studyDays ?? {},
       activity = activity ?? {},
       seconds = seconds ?? {},
       cards = cards ?? {},
       badges = badges ?? {},
       events = events ?? {},
       quizzes = quizzes ?? [];

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    name: j['name'] as String,
    classLevel: j['classLevel'] as int,
    avatar: j['avatar'] as int,
    stars: j['stars'] as int? ?? 0,
    xp: j['xp'] as int? ?? 0,
    streak: j['streak'] as int? ?? 0,
    lastStudyDay: j['lastStudyDay'] as String?,
    studyDays: {...?(j['studyDays'] as List?)?.cast<String>()},
    activity: {
      for (final e in ((j['activity'] as Map?) ?? {}).entries)
        e.key as String: e.value as int,
    },
    seconds: {
      for (final e in ((j['seconds'] as Map?) ?? {}).entries)
        e.key as String: e.value as int,
    },
    cards: {
      for (final e in ((j['cards'] as Map?) ?? {}).entries)
        e.key as String: CardState.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        ),
    },
    // Version 1 stored badges as a plain list without dates.
    badges: switch (j['badges']) {
      final Map<String, dynamic> m => m.cast<String, String>(),
      final List<dynamic> l => {for (final id in l.cast<String>()) id: ''},
      _ => {},
    },
    events: {...?(j['events'] as List?)?.cast<String>()},
    quizzes: [
      for (final q in (j['quizzes'] as List?) ?? const [])
        QuizRecord.fromJson((q as Map).cast<String, dynamic>()),
    ],
    goalDay: j['goalDay'] as String?,
    goalDone: j['goalDone'] as int? ?? 0,
    lastSubjectId: j['lastSubjectId'] as String?,
    lastChapterId: j['lastChapterId'] as String?,
    lastStudiedAt: j['lastStudiedAt'] == null
        ? null
        : DateTime.parse(j['lastStudiedAt'] as String),
    goalCards: j['goalCards'] as int?,
    covered: {...?(j['covered'] as List?)?.cast<String>()},
    exams: [
      for (final e in (j['exams'] as List?) ?? const [])
        Exam.fromJson((e as Map).cast<String, dynamic>()),
    ],
    owlColor: j['owlColor'] as String? ?? 'purple',
    owlHat: j['owlHat'] as String? ?? 'none',
  );

  final String id;
  String name;
  int classLevel;

  /// Index into the avatar palette.
  int avatar;

  int stars;
  int xp;
  int streak;

  /// yyyy-mm-dd of the last day a session was finished.
  String? lastStudyDay;
  final Set<String> studyDays;

  /// Cards reviewed plus quiz questions answered, per yyyy-mm-dd.
  final Map<String, int> activity;

  /// Seconds spent in sessions and quizzes, per yyyy-mm-dd.
  final Map<String, int> seconds;

  /// Scheduling state per card id. Cards without an entry are new.
  final Map<String, CardState> cards;

  /// Badge id → yyyy-mm-dd it was earned ('' if unknown).
  final Map<String, String> badges;

  /// One-off achievements that badges look for, such as 'earlyBird'.
  final Set<String> events;

  /// Finished quizzes, oldest first.
  final List<QuizRecord> quizzes;

  /// Cards reviewed on [goalDay] count towards the daily goal ring.
  String? goalDay;
  int goalDone;

  String? lastSubjectId;
  String? lastChapterId;
  DateTime? lastStudiedAt;

  /// Cards a day the student chose; null means the default for their age.
  int? goalCards;

  /// Chapters their class has done at school. Empty means all of them, so
  /// new cards come from everywhere until the student picks.
  final Set<String> covered;

  /// Tests coming up, soonest first.
  final List<Exam> exams;

  /// Ullu's look, from the wardrobe on the Me tab.
  String owlColor;
  String owlHat;

  bool get isJunior => classLevel <= 5;
  int get dailyGoal => goalCards ?? defaultGoal;
  int get defaultGoal => isJunior ? 10 : 30;

  /// The daily goal choices, in cards: light, normal, keen.
  List<int> get goalChoices =>
      isJunior ? const [5, 10, 15] : const [15, 30, 45];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'classLevel': classLevel,
    'avatar': avatar,
    'stars': stars,
    'xp': xp,
    'streak': streak,
    'lastStudyDay': lastStudyDay,
    'studyDays': studyDays.toList(),
    'activity': activity,
    'seconds': seconds,
    'cards': {for (final e in cards.entries) e.key: e.value.toJson()},
    'badges': badges,
    'events': events.toList(),
    'quizzes': [for (final q in quizzes) q.toJson()],
    'goalDay': goalDay,
    'goalDone': goalDone,
    'lastSubjectId': lastSubjectId,
    'lastChapterId': lastChapterId,
    'lastStudiedAt': lastStudiedAt?.toIso8601String(),
    'goalCards': goalCards,
    'covered': covered.toList(),
    'exams': [for (final e in exams) e.toJson()],
    'owlColor': owlColor,
    'owlHat': owlHat,
  };
}
