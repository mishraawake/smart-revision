import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_revision/data/deck_repository.dart';
import 'package:smart_revision/data/profile_store.dart';
import 'package:smart_revision/logic/quiz.dart';
import 'package:smart_revision/models/deck.dart';
import 'package:smart_revision/models/profile.dart';
import 'package:smart_revision/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime clock;
  late AppState state;

  Future<AppState> fresh() async {
    final s = AppState(
      decks: DeckRepository(),
      store: ProfileStore(),
      clock: () => clock,
    );
    await s.load();
    return s;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 23, 18);
    state = await fresh();
    await state.addProfile('Aarav', 2);
    await state.select(state.profiles.single);
  });

  test('a junior session mixes subjects and is capped by the daily goal', () {
    final queue = state.todayQueue();
    expect(queue, hasLength(state.current!.dailyGoal));
    expect(queue.map((c) => c.subjectId).toSet(), {'maths', 'english'});
  });

  test(
    'finishing a session awards stars, streak and the first badge',
    () async {
      final queue = state.todayQueue();
      for (final c in queue) {
        await state.answer(c, knew: c != queue.last);
      }
      final summary = await state.finishSession(
        knew: 9,
        missed: [queue.last],
        duration: const Duration(minutes: 5),
        goalDoneBefore: 0,
      );
      expect(summary.goalReached, isTrue);
      expect(summary.starsEarned, 10 + 3);
      expect(summary.streakBefore, 0);
      expect(summary.streakAfter, 1);
      expect(summary.newBadges, isEmpty, reason: 'Quiz badges need a quiz');
      expect(state.goalDoneToday, 10);
    },
  );

  test('missed cards come back after 10 minutes; known ones do not', () async {
    final queue = state.todayQueue();
    await state.answer(queue[0], knew: false);
    await state.answer(queue[1], knew: true);
    clock = clock.add(const Duration(minutes: 11));
    expect(state.todayCards().first, queue[0]);
    expect(state.todayCards(), isNot(contains(queue[1])));
  });

  test('streak grows on consecutive days and lapses after a gap', () async {
    Future<void> studyOneCard() async {
      await state.answer(state.todayQueue().first, knew: true);
      await state.finishSession(
        knew: 1,
        missed: const [],
        duration: Duration.zero,
        goalDoneBefore: 0,
      );
    }

    await studyOneCard();
    clock = clock.add(const Duration(days: 1));
    await studyOneCard();
    expect(state.streakOf(state.current!), 2);

    clock = clock.add(const Duration(days: 2));
    expect(state.streakOf(state.current!), 0);
  });

  test('practice answers do not change scheduling or stars', () async {
    final card = state.todayQueue().first;
    await state.answer(card, knew: true, practice: true);
    final summary = await state.finishSession(
      knew: 1,
      missed: const [],
      duration: Duration.zero,
      goalDoneBefore: 0,
      practice: true,
    );
    expect(state.stateOf(card), isNull);
    expect(summary.starsEarned, 0);
    expect(state.current!.stars, 0);
  });

  test('progress survives a restart', () async {
    final card = state.todayQueue().first;
    await state.answer(card, knew: true);

    final restarted = await fresh();
    await restarted.select(restarted.profiles.single);
    expect(restarted.stateOf(card)?.learnt, isTrue);
    expect(restarted.lastWasJunior, isTrue);
  });

  test('classes without decks load no content', () async {
    await state.addProfile('Kabir', 11);
    await state.select(state.profiles.last);
    expect(state.deck, isNull);
    expect(state.todayQueue(), isEmpty);
  });

  group('quizzes', () {
    /// Answers every question: right on even turns, wrong on odd ones.
    QuizSession playHalfRight(List<QuizQuestion> questions) {
      final quiz = QuizSession(questions);
      while (!quiz.finished) {
        quiz.record(QuizAnswer(quiz.current, correct: quiz.index.isEven));
      }
      return quiz;
    }

    QuizSession playAllRight(List<QuizQuestion> questions) {
      final quiz = QuizSession(questions);
      while (!quiz.finished) {
        quiz.record(QuizAnswer(quiz.current, correct: true));
      }
      return quiz;
    }

    Chapter groups() => state.deck!.subjects.first.chapters[1];

    test('a Junior chapter quiz has 5 questions from that chapter', () {
      final ch = groups();
      final qs = state.chapterQuiz(ch);
      expect(qs, hasLength(5));
      expect(
        qs.every((q) => q.card == null || q.card!.chapterId == ch.id),
        isTrue,
      );
      expect(qs.whereType<MatchQuestion>(), hasLength(1));
    });

    test('a mixed quiz spreads questions across subjects', () async {
      await state.addProfile('Diya', 8);
      await state.select(state.profiles.last);
      final qs = state.mixedQuiz(count: 20);
      expect(qs, hasLength(20));
      expect(
        {
          for (final q in qs)
            if (q.card != null) q.card!.subjectId,
        },
        {'science', 'maths', 'social', 'english'},
      );
    });

    test(
      'a counted quiz schedules cards, gives XP and keeps history',
      () async {
        final ch = groups();
        final quiz = playHalfRight(state.chapterQuiz(ch));
        final summary = await state.finishQuiz(
          quiz,
          chapter: ch,
          duration: const Duration(minutes: 2),
        );

        expect(summary.score, 3);
        expect(summary.quizStars, 1);
        expect(summary.starsEarned, 3);
        expect(summary.xpEarned, 3 * 10);
        expect(state.current!.xp, 30);
        for (final a in quiz.answers) {
          if (a.question.card case final c?) {
            expect(state.stateOf(c)!.learnt, a.correct);
          }
        }
        expect(state.bestQuiz(ch.id)!.score, 3);
        expect(state.activityOn(clock), 5);
        expect(summary.newBadges.map((b) => b.id), contains('firstQuiz'));
        expect(state.current!.badges['firstQuiz'], '2026-10-23');
      },
    );

    test(
      'three stars earn the bonus, and a perfect 5 earns its badge',
      () async {
        final ch = groups();
        final summary = await state.finishQuiz(
          playAllRight(state.chapterQuiz(ch)),
          chapter: ch,
          duration: const Duration(minutes: 1),
        );
        expect(summary.quizStars, 3);
        expect(summary.xpEarned, 5 * 10 + 20);
        expect(summary.newBadges.map((b) => b.id), contains('perfect5'));
      },
    );

    test('a hint costs 5 XP on a right answer', () async {
      final ch = groups();
      final quiz = QuizSession(state.chapterQuiz(ch));
      quiz.record(QuizAnswer(quiz.current, correct: true, hintUsed: true));
      while (!quiz.finished) {
        quiz.record(QuizAnswer(quiz.current, correct: false));
      }
      final summary = await state.finishQuiz(
        quiz,
        chapter: ch,
        duration: Duration.zero,
      );
      expect(summary.xpEarned, 5);
    });

    test('mastery mixes learnt cards with the best quiz score', () async {
      final ch = groups();
      expect(state.chapterMastery(ch), 0);
      await state.finishQuiz(
        playAllRight(state.chapterQuiz(ch)),
        chapter: ch,
        duration: Duration.zero,
      );
      final learnt = state.learntFraction(ch.cards);
      expect(state.chapterMastery(ch), closeTo((learnt + 1) / 2, 1e-9));
      final (stars, max) = state.subjectQuizStars(state.deck!.subjects.first);
      expect(stars, 3);
      expect(max, 3 * state.deck!.subjects.first.chapters.length);
    });

    test('a just-for-fun quiz changes nothing', () async {
      final ch = groups();
      final quiz = playHalfRight(state.chapterQuiz(ch));
      final summary = await state.finishQuiz(
        quiz,
        chapter: ch,
        duration: Duration.zero,
        countsTowardsRevision: false,
      );

      expect(summary.starsEarned, 0);
      expect(summary.xpEarned, 0);
      expect(state.current!.stars, 0);
      expect(state.current!.quizzes, isEmpty);
      expect(state.goalDoneToday, 0);
    });
  });

  test('profiles saved before quizzes still load', () {
    final old = Profile.fromJson({
      'id': '1',
      'name': 'Arrav',
      'classLevel': 5,
      'avatar': 0,
      'stars': 13,
      'badges': ['first', 'learnt10'],
    });
    expect(old.xp, 0);
    expect(old.quizzes, isEmpty);
    expect(old.badges, {'first': '', 'learnt10': ''});
    final round = Profile.fromJson(old.toJson());
    expect(round.stars, 13);
    expect(round.badges.keys, ['first', 'learnt10']);
  });

  test(
    'a comeback after a break and an early session are remembered',
    () async {
      await state.answer(state.todayQueue().first, knew: true);
      await state.finishSession(
        knew: 1,
        missed: const [],
        duration: Duration.zero,
        goalDoneBefore: 0,
      );
      clock = DateTime(2026, 10, 28, 7);
      await state.answer(state.todayQueue().first, knew: true);
      await state.finishSession(
        knew: 1,
        missed: const [],
        duration: Duration.zero,
        goalDoneBefore: 0,
      );
      expect(state.current!.events, containsAll(['comeback', 'earlyBird']));
    },
  );
}
