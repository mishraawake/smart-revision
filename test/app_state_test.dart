import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_revision/data/deck_repository.dart';
import 'package:smart_revision/data/profile_store.dart';
import 'package:smart_revision/logic/quiz.dart';
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
      expect(summary.newBadges.map((b) => b.id), contains('first'));
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
    QuizSession playHalfRight(List<QuizQuestion> questions) {
      final quiz = QuizSession(questions);
      while (!quiz.finished) {
        final q = quiz.current;
        quiz.answer(
          quiz.index.isEven
              ? q.correctIndex
              : (q.correctIndex + 1) % q.options.length,
        );
      }
      return quiz;
    }

    test('a chapter quiz only asks about that chapter', () {
      final ch = state.deck!.subjects.first.chapters[1];
      final qs = state.chapterQuiz(ch);
      expect(qs, hasLength(ch.cards.length));
      expect(qs.every((q) => q.card.chapterId == ch.id), isTrue);
    });

    test('a mixed quiz spreads questions across subjects', () async {
      await state.addProfile('Diya', 8);
      await state.select(state.profiles.last);
      final qs = state.mixedQuiz(count: 20);
      expect(qs, hasLength(20));
      expect(qs.map((q) => q.card.subjectId).toSet(), {
        'science',
        'maths',
        'social',
        'english',
      });
    });

    test(
      'a counted quiz schedules cards and stars correct answers only',
      () async {
        final ch = state.deck!.subjects.first.chapters[1];
        final quiz = playHalfRight(state.chapterQuiz(ch));
        final summary = await state.finishQuiz(
          quiz,
          duration: const Duration(minutes: 2),
        );

        expect(summary.knew, quiz.score);
        expect(summary.starsEarned, quiz.score);
        for (final a in quiz.answers) {
          expect(state.stateOf(a.question.card)!.learnt, a.correct);
        }
        expect(state.goalDoneToday, quiz.answers.length);
      },
    );

    test('a just-for-fun quiz changes nothing', () async {
      final ch = state.deck!.subjects.first.chapters[1];
      final quiz = playHalfRight(state.chapterQuiz(ch));
      final summary = await state.finishQuiz(
        quiz,
        duration: Duration.zero,
        countsTowardsRevision: false,
      );

      expect(summary.starsEarned, 0);
      expect(state.current!.stars, 0);
      expect(state.goalDoneToday, 0);
      expect(
        quiz.answers.every((a) => state.stateOf(a.question.card) == null),
        isTrue,
      );
    });
  });
}
