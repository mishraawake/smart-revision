import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/deck_repository.dart';
import '../data/profile_store.dart';
import '../logic/badges.dart';
import '../logic/quiz.dart';
import '../logic/scheduler.dart';
import '../models/deck.dart';
import '../models/profile.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SessionSummary {
  SessionSummary({
    required this.knew,
    required this.missed,
    required this.duration,
    required this.starsEarned,
    required this.streakBefore,
    required this.streakAfter,
    required this.goalReached,
    required this.newBadges,
    required this.dueTomorrow,
    required this.practice,
  });

  final int knew;
  final List<Flashcard> missed;
  final Duration duration;
  final int starsEarned;
  final int streakBefore;
  final int streakAfter;
  final bool goalReached;
  final List<BadgeDef> newBadges;
  final int dueTomorrow;
  final bool practice;

  int get total => knew + missed.length;
}

class AppState extends ChangeNotifier {
  AppState({
    required this.decks,
    required this.store,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final DeckRepository decks;
  final ProfileStore store;
  final DateTime Function() now;

  List<Profile> profiles = [];
  Profile? current;
  ClassDeck? deck;
  bool loaded = false;

  /// Tier of the last student who used the phone; picks the picker layout.
  bool lastWasJunior = false;

  int get sessionSize => current!.isJunior ? 12 : 15;

  Future<void> load() async {
    profiles = await store.loadProfiles();
    final lastId = await store.loadLastProfileId();
    lastWasJunior =
        profiles.where((p) => p.id == lastId).firstOrNull?.isJunior ?? false;
    loaded = true;
    notifyListeners();
  }

  Future<void> addProfile(String name, int classLevel) async {
    profiles.add(
      Profile(
        id: '${now().microsecondsSinceEpoch}',
        name: name.trim(),
        classLevel: classLevel,
        avatar: profiles.length,
      ),
    );
    await store.saveProfiles(profiles);
    notifyListeners();
  }

  Future<void> select(Profile p) async {
    current = p;
    deck = await decks.load(p.classLevel);
    lastWasJunior = p.isJunior;
    await store.saveLastProfileId(p.id);
    notifyListeners();
  }

  void signOut() {
    current = null;
    deck = null;
    notifyListeners();
  }

  // ---- Progress -----------------------------------------------------------

  /// Streak as it stands today: it lapses if neither today nor yesterday was
  /// a study day.
  int streakOf(Profile p) {
    final last = p.lastStudyDay;
    if (last == null) return 0;
    final today = now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    return last == dayKey(today) || last == dayKey(yesterday) ? p.streak : 0;
  }

  int get goalDoneToday {
    final p = current!;
    return p.goalDay == dayKey(now()) ? p.goalDone : 0;
  }

  double learntFraction(Iterable<Flashcard> cards) {
    final list = cards.toList();
    if (list.isEmpty) return 0;
    final learnt = list
        .where((c) => current!.cards[c.id]?.learnt ?? false)
        .length;
    return learnt / list.length;
  }

  bool isStarted(Chapter ch) =>
      ch.cards.any((c) => current!.cards.containsKey(c.id));

  bool _isDue(Flashcard c, DateTime at) {
    final s = current!.cards[c.id];
    return s != null && !s.due.isAfter(at);
  }

  /// Seen cards that are due now, oldest first.
  List<Flashcard> _dueReviews(Iterable<Flashcard> cards, DateTime at) {
    final due = cards.where((c) => _isDue(c, at)).toList()
      ..sort(
        (a, b) =>
            current!.cards[a.id]!.due.compareTo(current!.cards[b.id]!.due),
      );
    return due;
  }

  /// New cards in teaching order, taking one from each subject in turn so a
  /// session is not all one subject. The last chapter studied comes first.
  List<Flashcard> _newCards() {
    final p = current!;
    final subjects = [
      ...deck!.subjects.where((s) => s.id == p.lastSubjectId),
      ...deck!.subjects.where((s) => s.id != p.lastSubjectId),
    ];
    final perSubject = [
      for (final s in subjects)
        [
          for (final ch in [
            ...s.chapters.where((c) => c.id == p.lastChapterId),
            ...s.chapters.where((c) => c.id != p.lastChapterId),
          ])
            ...ch.cards.where((c) => !p.cards.containsKey(c.id)),
        ],
    ];
    final out = <Flashcard>[];
    for (var i = 0; perSubject.any((l) => i < l.length); i++) {
      for (final l in perSubject) {
        if (i < l.length) out.add(l[i]);
      }
    }
    return out;
  }

  int get _newAllowance =>
      (current!.dailyGoal - goalDoneToday).clamp(0, current!.dailyGoal);

  /// Everything waiting today: due reviews plus new cards up to the goal.
  List<Flashcard> todayCards() {
    if (deck == null) return [];
    return [
      ..._dueReviews(deck!.allCards, now()),
      ..._newCards().take(_newAllowance),
    ];
  }

  List<Flashcard> todayQueue() => todayCards().take(sessionSize).toList();

  Map<String, int> dueBySubject() {
    final counts = <String, int>{};
    for (final c in todayCards()) {
      counts[c.subjectId] = (counts[c.subjectId] ?? 0) + 1;
    }
    return counts;
  }

  /// Due cards in a chapter, then its new cards.
  List<Flashcard> chapterQueue(Chapter ch) => [
    ..._dueReviews(ch.cards, now()),
    ...ch.cards.where((c) => !current!.cards.containsKey(c.id)),
  ].take(sessionSize).toList();

  int chapterDue(Chapter ch) => _dueReviews(ch.cards, now()).length;

  /// Learnt cards, for practising after everything due is done.
  List<Flashcard> practiceQueue() {
    if (deck == null) return [];
    return (deck!.allCards
            .where((c) => current!.cards[c.id]?.learnt ?? false)
            .toList()
          ..shuffle())
        .take(sessionSize)
        .toList();
  }

  // ---- Quizzes ------------------------------------------------------------

  /// Up to [count] questions from one chapter.
  List<QuizQuestion> chapterQuiz(
    Chapter ch, {
    int count = 10,
    Random? random,
  }) => QuizBuilder.build(
    ch.cards,
    pool: deck!.allCards,
    count: count,
    random: random,
  );

  /// Up to [count] questions across every subject, spread evenly.
  List<QuizQuestion> mixedQuiz({int count = 20, Random? random}) {
    if (deck == null) return [];
    final rng = random ?? Random();
    final perSubject = [
      for (final s in deck!.subjects) s.cards.toList()..shuffle(rng),
    ];
    final picked = <Flashcard>[];
    for (
      var i = 0;
      picked.length < count && perSubject.any((l) => i < l.length);
      i++
    ) {
      for (final l in perSubject) {
        if (i < l.length && picked.length < count) picked.add(l[i]);
      }
    }
    return QuizBuilder.build(
      picked,
      pool: deck!.allCards,
      count: count,
      random: rng,
    );
  }

  /// Records a finished quiz. When it [countsTowardsRevision], every answer
  /// schedules its card like "Knew it" / "Didn't know" and earns stars;
  /// otherwise it is just for fun.
  Future<SessionSummary> finishQuiz(
    QuizSession quiz, {
    required Duration duration,
    bool countsTowardsRevision = true,
  }) async {
    final goalBefore = goalDoneToday;
    for (final a in quiz.answers) {
      await answer(
        a.question.card,
        knew: a.correct,
        practice: !countsTowardsRevision,
      );
    }
    return finishSession(
      knew: quiz.score,
      missed: quiz.missed,
      duration: duration,
      goalDoneBefore: goalBefore,
      practice: !countsTowardsRevision,
      quiz: true,
    );
  }

  int dueOn(DateTime day) {
    if (deck == null) return 0;
    final end = DateTime(day.year, day.month, day.day + 1);
    return deck!.allCards.where((c) => _isDue(c, end)).length;
  }

  Chapter? get lastChapter {
    final id = current?.lastChapterId;
    if (id == null || deck == null) return null;
    return deck!.subjects
        .expand((s) => s.chapters)
        .where((c) => c.id == id)
        .firstOrNull;
  }

  Subject? subjectById(String id) =>
      deck?.subjects.where((s) => s.id == id).firstOrNull;

  /// Days this week (Sunday first) that had a finished session.
  List<bool> weekStudied() {
    final t = now();
    final sunday = DateTime(t.year, t.month, t.day - t.weekday % 7);
    return [
      for (var i = 0; i < 7; i++)
        current!.studyDays.contains(
          dayKey(DateTime(sunday.year, sunday.month, sunday.day + i)),
        ),
    ];
  }

  // ---- Answering ----------------------------------------------------------

  CardState? stateOf(Flashcard c) => current!.cards[c.id];

  Future<void> answer(
    Flashcard card, {
    required bool knew,
    bool practice = false,
  }) async {
    final p = current!;
    final t = now();
    if (!practice) {
      p.cards[card.id] = Scheduler.grade(p.cards[card.id], knew: knew, now: t);
      final today = dayKey(t);
      if (p.goalDay != today) {
        p.goalDay = today;
        p.goalDone = 0;
      }
      p.goalDone++;
    }
    p.lastSubjectId = card.subjectId;
    p.lastChapterId = card.chapterId;
    p.lastStudiedAt = t;
    await store.saveProfiles(profiles);
    notifyListeners();
  }

  /// Awards stars, streak and badges once a session ends.
  Future<SessionSummary> finishSession({
    required int knew,
    required List<Flashcard> missed,
    required Duration duration,
    required int goalDoneBefore,
    bool practice = false,
    bool quiz = false,
  }) async {
    final p = current!;
    final t = now();
    final today = dayKey(t);
    final streakBefore = streakOf(p);
    var stars = 0;
    var goalReached = false;
    final newBadges = <BadgeDef>[];

    if (!practice) {
      final reviewed = knew + missed.length;
      goalReached =
          goalDoneBefore < p.dailyGoal && goalDoneToday >= p.dailyGoal;
      // Flashcards reward effort; quizzes reward correct answers.
      stars = (quiz ? knew : reviewed) + (goalReached ? 3 : 0);
      p.stars += stars;
      if (p.lastStudyDay != today) {
        p.streak = streakBefore + 1;
        p.lastStudyDay = today;
      }
      p.studyDays.add(today);
      for (final b in BadgeDef.all) {
        if (!p.badges.contains(b.id) && b.earned(p, deck)) {
          p.badges.add(b.id);
          newBadges.add(b);
        }
      }
      await store.saveProfiles(profiles);
      notifyListeners();
    }

    return SessionSummary(
      knew: knew,
      missed: missed,
      duration: duration,
      starsEarned: stars,
      streakBefore: streakBefore,
      streakAfter: streakOf(p),
      goalReached: goalReached,
      newBadges: newBadges,
      dueTomorrow: dueOn(DateTime(t.year, t.month, t.day + 1)),
      practice: practice,
    );
  }
}

/// Gives screens access to [AppState] and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
