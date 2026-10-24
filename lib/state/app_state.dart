import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/deck_repository.dart';
import '../data/profile_store.dart';
import '../logic/badges.dart';
import '../logic/levels.dart';
import '../logic/quiz.dart';
import '../logic/scheduler.dart';
import '../models/deck.dart';
import '../models/profile.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// How far along a chapter is, in words a student understands.
enum ChapterLevel {
  notStarted('Not started'),
  learning('Learning'),
  strong('Strong'),
  mastered('Mastered');

  const ChapterLevel(this.label);
  final String label;
}

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
    this.xpEarned = 0,
  });

  final int knew;
  final List<Flashcard> missed;
  final Duration duration;
  final int starsEarned;
  final int xpEarned;
  final int streakBefore;
  final int streakAfter;
  final bool goalReached;
  final List<BadgeDef> newBadges;
  final int dueTomorrow;
  final bool practice;

  int get total => knew + missed.length;
}

class QuizSummary {
  QuizSummary({
    required this.quiz,
    required this.duration,
    required this.quizStars,
    required this.starsEarned,
    required this.xpEarned,
    required this.previousBest,
    required this.session,
  });

  final QuizSession quiz;
  final Duration duration;

  /// 0–3 stars for this quiz's score.
  final int quizStars;

  /// Stars added to the student's total (one per right answer).
  final int starsEarned;
  final int xpEarned;

  /// Best earlier score on the same chapter quiz, if any.
  final QuizRecord? previousBest;
  final SessionSummary session;

  int get score => quiz.score;
  int get total => quiz.total;
  List<BadgeDef> get newBadges => session.newBadges;
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
    // A phone with one student is that student's: open straight to them.
    if (profiles.length == 1) {
      current = profiles.first;
      deck = await decks.load(current!.classLevel);
      lastWasJunior = current!.isJunior;
    }
    loaded = true;
    notifyListeners();
  }

  /// Told when a session or quiz has been saved, to sync it.
  void Function()? onSessionEnd;

  /// Saves every profile and redraws, after progress was changed from
  /// outside (merged in from another phone).
  Future<void> persist() async {
    await store.saveProfiles(profiles);
    notifyListeners();
  }

  /// Told about profiles made on this phone, so they can be saved to the
  /// parent's account.
  void Function(Profile p)? onProfileAdded;

  /// [id] is given when the child already exists on the server (an approved
  /// student, or one restored on a new phone); those aren't reported back.
  Future<Profile> addProfile(
    String name,
    int classLevel, {
    int? avatar,
    String? id,
  }) async {
    final p = Profile(
      id: id ?? '${now().microsecondsSinceEpoch}',
      name: name.trim(),
      classLevel: classLevel,
      avatar: avatar ?? profiles.length,
    );
    profiles.add(p);
    await store.saveProfiles(profiles);
    notifyListeners();
    if (id == null) onProfileAdded?.call(p);
    return p;
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

  Level get level => Level.of(current!.xp);

  double learntFraction(Iterable<Flashcard> cards) {
    final list = cards.toList();
    if (list.isEmpty) return 0;
    final learnt = list
        .where((c) => current!.cards[c.id]?.learnt ?? false)
        .length;
    return learnt / list.length;
  }

  bool isStarted(Chapter ch) =>
      ch.cards.any((c) => current!.cards.containsKey(c.id)) ||
      bestQuiz(ch.id) != null;

  /// Best score on this chapter's quiz.
  QuizRecord? bestQuiz(String chapterId) {
    QuizRecord? best;
    for (final q in current!.quizzes) {
      if (q.chapterId != chapterId) continue;
      if (best == null || q.accuracy > best.accuracy) best = q;
    }
    return best;
  }

  /// Cards you know well plus quiz accuracy: the average of the learnt share
  /// and the best quiz score, or just the learnt share before any quiz.
  double chapterMastery(Chapter ch) {
    final learnt = learntFraction(ch.cards);
    final best = bestQuiz(ch.id);
    return best == null ? learnt : (learnt + best.accuracy) / 2;
  }

  double subjectMastery(Subject s) => s.chapters.isEmpty
      ? 0
      : s.chapters.map(chapterMastery).reduce((a, b) => a + b) /
            s.chapters.length;

  /// Best quiz stars across the subject's chapters, out of 3 per chapter.
  (int earned, int max) subjectQuizStars(Subject s) {
    var earned = 0;
    for (final ch in s.chapters) {
      final best = bestQuiz(ch.id);
      if (best != null) earned += quizStars(best.score, best.total);
    }
    return (earned, s.chapters.length * 3);
  }

  /// Finished quizzes, newest first.
  List<QuizRecord> get quizHistory => current!.quizzes.reversed.toList();

  /// Cards and questions done on [day].
  int activityOn(DateTime day) => current!.activity[dayKey(day)] ?? 0;

  bool studiedOn(DateTime day) =>
      current!.studyDays.contains(dayKey(day)) || activityOn(day) > 0;

  Chapter? chapterById(String? id) =>
      id == null ? null : deck?.chapters.where((c) => c.id == id).firstOrNull;

  BadgeFacts badgeFacts() {
    final p = current!;
    final learnt = <String, int>{};
    for (final c in deck?.allCards ?? const <Flashcard>[]) {
      if (p.cards[c.id]?.learnt ?? false) {
        learnt[c.subjectId] = (learnt[c.subjectId] ?? 0) + 1;
      }
    }
    return BadgeFacts(
      profile: p,
      streak: streakOf(p),
      learntBySubject: learnt,
      subjectIds: {...?deck?.subjects.map((s) => s.id)},
      masteredChapters: {
        for (final s in deck?.subjects ?? const <Subject>[])
          s.id: (
            s.chapters.where((ch) => chapterMastery(ch) >= 0.8).length,
            s.chapters.length,
          ),
      },
    );
  }

  List<BadgeDef> get badgeList {
    final facts = badgeFacts();
    return [
      for (final b in BadgeDef.forTier(junior: current!.isJunior))
        if (b.availableFor(facts)) b,
    ];
  }

  // ---- Review queues ------------------------------------------------------

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
            if (isCovered(ch))
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

  // ---- My chapters, mistakes, tests ---------------------------------------

  /// Done at school, or every chapter while the student hasn't picked.
  bool isCovered(Chapter ch) =>
      current!.covered.isEmpty || current!.covered.contains(ch.id);

  ChapterLevel levelOf(Chapter ch) {
    if (!isStarted(ch)) return ChapterLevel.notStarted;
    final m = chapterMastery(ch);
    return m >= 0.8
        ? ChapterLevel.mastered
        : m >= 0.5
        ? ChapterLevel.strong
        : ChapterLevel.learning;
  }

  /// Cards whose last answer was wrong, most recent first. Answering one
  /// right takes it off the list.
  List<Flashcard> mistakes() {
    final p = current!;
    final out = [
      for (final c in deck?.allCards ?? const <Flashcard>[])
        if (p.cards[c.id] case final s? when s.box == 0 && s.at != null) c,
    ];
    out.sort((a, b) => p.cards[b.id]!.at!.compareTo(p.cards[a.id]!.at!));
    return out;
  }

  /// Tests from today on, soonest first.
  List<Exam> get upcomingExams {
    final today = dayKey(now());
    return [
      for (final e in current!.exams)
        if (e.day.compareTo(today) >= 0) e,
    ]..sort((a, b) => a.day.compareTo(b.day));
  }

  List<Chapter> examChapters(Exam e) => [
    for (final ch in deck?.chapters ?? const <Chapter>[])
      if (e.chapterIds.contains(ch.id)) ch,
  ];

  /// Average mastery of the test's chapters, 0–1.
  double examReadiness(Exam e) {
    final chs = examChapters(e);
    if (chs.isEmpty) return 0;
    return chs.map(chapterMastery).reduce((a, b) => a + b) / chs.length;
  }

  int daysUntil(Exam e) {
    final t = now();
    return e.date.difference(DateTime(t.year, t.month, t.day)).inDays;
  }

  /// Cards not learnt yet across the test's chapters.
  int examCardsLeft(Exam e) =>
      [for (final ch in examChapters(e)) ...ch.cards]
          .where((c) => !(current!.cards[c.id]?.learnt ?? false))
          .length;

  /// Revision for a test: mistakes first, then cards never seen, then the
  /// learnt ones that are due soonest.
  List<Flashcard> examQueue(Exam e) {
    final p = current!;
    final cards = [for (final ch in examChapters(e)) ...ch.cards];
    int rank(Flashcard c) {
      final s = p.cards[c.id];
      if (s == null) return 1;
      if (s.box == 0) return 0;
      return 2;
    }

    cards.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final da = p.cards[a.id]?.due;
      final db = p.cards[b.id]?.due;
      return da == null || db == null ? 0 : da.compareTo(db);
    });
    return cards.take(sessionSize).toList();
  }

  // ---- The student's own choices -----------------------------------------

  /// Told when a child's name, class or avatar changed, to update their
  /// record on the parent's account.
  void Function(Profile p)? onProfileEdited;

  Future<void> editProfile({
    required String name,
    required int classLevel,
    required int avatar,
  }) async {
    final p = current!;
    final newClass = classLevel != p.classLevel;
    p
      ..name = name.trim()
      ..classLevel = classLevel
      ..avatar = avatar;
    if (newClass) {
      // Chapters and tests belong to the old class's books.
      p.covered.clear();
      p.exams.clear();
      p.goalCards = null;
      deck = await decks.load(classLevel);
      lastWasJunior = p.isJunior;
    }
    await persist();
    onProfileEdited?.call(p);
  }

  Future<void> setGoal(int cards) async {
    current!.goalCards = cards;
    await persist();
  }

  Future<void> setCovered(String chapterId, {required bool done}) async {
    final c = current!.covered;
    done ? c.add(chapterId) : c.remove(chapterId);
    await persist();
  }

  Future<void> dressOwl({String? colour, String? hat}) async {
    final p = current!;
    if (colour != null) p.owlColor = colour;
    if (hat != null) p.owlHat = hat;
    await persist();
  }

  Future<void> addExam(String subjectId, DateTime day, List<String> chapters) {
    current!.exams.add(
      Exam(
        id: '${now().microsecondsSinceEpoch}',
        subjectId: subjectId,
        day: dayKey(day),
        chapterIds: chapters,
      ),
    );
    current!.exams.sort((a, b) => a.day.compareTo(b.day));
    return persist();
  }

  Future<void> removeExam(Exam e) {
    current!.exams.remove(e);
    return persist();
  }

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

  int dueOn(DateTime day) {
    if (deck == null) return 0;
    final end = DateTime(day.year, day.month, day.day + 1);
    return deck!.allCards.where((c) => _isDue(c, end)).length;
  }

  Chapter? get lastChapter => chapterById(current?.lastChapterId);

  Subject? subjectById(String id) =>
      deck?.subjects.where((s) => s.id == id).firstOrNull;

  /// Days this week (Sunday first) that had a finished session.
  List<bool> weekStudied() {
    final t = now();
    final sunday = DateTime(t.year, t.month, t.day - t.weekday % 7);
    return [
      for (var i = 0; i < 7; i++)
        studiedOn(DateTime(sunday.year, sunday.month, sunday.day + i)),
    ];
  }

  // ---- Quizzes ------------------------------------------------------------

  /// Junior quizzes are always 5 questions; Senior picks 5, 8 or 10.
  int get defaultQuizLength => current!.isJunior ? 5 : 10;

  /// Questions from one chapter.
  List<QuizQuestion> chapterQuiz(Chapter ch, {int? count, Random? random}) =>
      QuizBuilder.build(
        ch.cards,
        pool: deck!.allCards,
        chapters: [ch],
        count: count ?? defaultQuizLength,
        junior: current!.isJunior,
        random: random,
      );

  /// Questions across every subject, spread evenly.
  List<QuizQuestion> mixedQuiz({int? count, Random? random}) {
    if (deck == null) return [];
    final n = count ?? (current!.isJunior ? 5 : 20);
    final rng = random ?? Random();
    final perSubject = [
      for (final s in deck!.subjects) s.cards.toList()..shuffle(rng),
    ];
    final picked = <Flashcard>[];
    for (
      var i = 0;
      picked.length < n && perSubject.any((l) => i < l.length);
      i++
    ) {
      for (final l in perSubject) {
        if (i < l.length && picked.length < n) picked.add(l[i]);
      }
    }
    return QuizBuilder.build(
      picked,
      pool: deck!.allCards,
      chapters: deck!.chapters,
      count: n,
      junior: current!.isJunior,
      random: rng,
    );
  }

  /// Records a finished quiz. When it [countsTowardsRevision], each answer
  /// schedules its card like "Knew it" / "Didn't know" (mistakes go back to
  /// the review deck), and XP, stars and history are kept; otherwise it is
  /// just for fun.
  Future<QuizSummary> finishQuiz(
    QuizSession quiz, {
    required Duration duration,
    Chapter? chapter,
    bool countsTowardsRevision = true,
  }) async {
    final p = current!;
    final goalBefore = goalDoneToday;
    final previousBest = chapter == null ? null : bestQuiz(chapter.id);
    final stars3 = quizStars(quiz.score, quiz.total);
    var xp = 0;

    if (countsTowardsRevision) {
      for (final a in quiz.answers) {
        if (a.question.card case final card?) {
          await answer(card, knew: a.correct, save: false);
        } else {
          _addActivity(1);
        }
        if (a.correct) {
          xp += Xp.perRightAnswer - (a.hintUsed ? Xp.hintCost : 0);
        }
      }
      if (stars3 == 3) xp += Xp.threeStarBonus;
      p.xp += xp;
      p.quizzes.add(
        QuizRecord(
          subjectId: chapter?.subjectId,
          chapterId: chapter?.id,
          at: now(),
          score: quiz.score,
          total: quiz.total,
          seconds: duration.inSeconds,
        ),
      );
      if (chapter != null) {
        p.lastSubjectId = chapter.subjectId;
        p.lastChapterId = chapter.id;
      }
    }
    final session = await finishSession(
      knew: quiz.score,
      missed: quiz.missed,
      duration: duration,
      goalDoneBefore: goalBefore,
      practice: !countsTowardsRevision,
      quiz: true,
    );
    return QuizSummary(
      quiz: quiz,
      duration: duration,
      quizStars: stars3,
      starsEarned: session.starsEarned,
      xpEarned: xp + session.xpEarned,
      previousBest: previousBest,
      session: session,
    );
  }

  // ---- Answering ----------------------------------------------------------

  CardState? stateOf(Flashcard c) => current!.cards[c.id];

  void _addActivity(int n) {
    final key = dayKey(now());
    current!.activity[key] = (current!.activity[key] ?? 0) + n;
  }

  Future<void> answer(
    Flashcard card, {
    required bool knew,
    bool practice = false,
    bool save = true,
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
      _addActivity(1);
    }
    p.lastSubjectId = card.subjectId;
    p.lastChapterId = card.chapterId;
    p.lastStudiedAt = t;
    if (save) {
      await store.saveProfiles(profiles);
      notifyListeners();
    }
  }

  /// Awards stars, streak, XP for the daily goal and badges once a session
  /// ends.
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
    var xp = 0;
    var goalReached = false;
    final newBadges = <BadgeDef>[];

    if (!practice) {
      final reviewed = knew + missed.length;
      goalReached =
          goalDoneBefore < p.dailyGoal && goalDoneToday >= p.dailyGoal;
      // Flashcards reward effort; quizzes reward correct answers.
      stars = (quiz ? knew : reviewed) + (goalReached ? 3 : 0);
      p.stars += stars;
      if (goalReached) {
        xp = Xp.dailyGoalBonus;
        p.xp += xp;
      }
      if (p.lastStudyDay != today) {
        final last = p.lastStudyDay == null
            ? null
            : DateTime.tryParse(p.lastStudyDay!);
        if (last != null &&
            DateTime(t.year, t.month, t.day).difference(last).inDays > 3) {
          p.events.add('comeback');
        }
        p.streak = streakBefore + 1;
        p.lastStudyDay = today;
      }
      if (t.hour < 8) p.events.add('earlyBird');
      p.studyDays.add(today);
      p.lastStudiedAt = t;
      final facts = badgeFacts();
      for (final b in BadgeDef.forTier(junior: p.isJunior)) {
        if (!p.badges.containsKey(b.id) &&
            b.availableFor(facts) &&
            b.earned(facts)) {
          p.badges[b.id] = today;
          newBadges.add(b);
        }
      }
    }
    // Practice counts as study time for the parent's minutes chart.
    p.seconds[today] = (p.seconds[today] ?? 0) + duration.inSeconds;
    await store.saveProfiles(profiles);
    notifyListeners();
    onSessionEnd?.call();

    return SessionSummary(
      knew: knew,
      missed: missed,
      duration: duration,
      starsEarned: stars,
      xpEarned: xp,
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
