import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_revision/app.dart';
import 'package:smart_revision/data/account_service.dart';
import 'package:smart_revision/data/deck_repository.dart';
import 'package:smart_revision/data/profile_store.dart';
import 'package:smart_revision/data/speaker.dart';
import 'package:smart_revision/logic/owl_wardrobe.dart';
import 'package:smart_revision/logic/progress_merge.dart';
import 'package:smart_revision/models/profile.dart';
import 'package:smart_revision/state/account_state.dart';
import 'package:smart_revision/state/app_state.dart';

import 'review_flow_test.dart' show tapAndWait;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the student\'s own choices', () {
    late DateTime clock;
    late AppState state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      clock = DateTime(2026, 10, 23, 18);
      state = AppState(
        decks: DeckRepository(),
        store: ProfileStore(),
        clock: () => clock,
      );
      await state.load();
      await state.addProfile('Diya', 8);
      await state.select(state.profiles.single);
    });

    test('a phone with one student opens straight to them', () async {
      final again = AppState(
        decks: DeckRepository(),
        store: ProfileStore(),
        clock: () => clock,
      );
      await again.load();
      expect(again.current?.name, 'Diya');
      expect(again.deck, isNotNull);
    });

    test('the chosen goal sets how many new cards come', () async {
      final p = state.current!;
      expect(p.dailyGoal, 30);
      await state.setGoal(15);
      expect(p.dailyGoal, 15);
      expect(state.todayCards(), hasLength(lessThanOrEqualTo(15)));
    });

    test('new cards come only from chapters done at school', () async {
      final science = state.deck!.subjects.firstWhere((s) => s.id == 'science');
      final ch1 = science.chapters.first;
      await state.setCovered(ch1.id, done: true);
      expect(state.todayCards().map((c) => c.chapterId).toSet(), {ch1.id});
      expect(state.isCovered(science.chapters.last), isFalse);
      await state.setCovered(ch1.id, done: false);
      expect(
        state.todayCards().map((c) => c.chapterId).toSet().length,
        greaterThan(1),
        reason: 'nothing ticked means every chapter',
      );
    });

    test('a wrong answer becomes a mistake until answered right', () async {
      final card = state.todayQueue().first;
      await state.answer(card, knew: false);
      expect(state.mistakes(), [card]);
      await state.answer(card, knew: true);
      expect(state.mistakes(), isEmpty);
    });

    test('chapter levels follow mastery', () async {
      final ch = state.deck!.chapters.first;
      expect(state.levelOf(ch), ChapterLevel.notStarted);
      await state.answer(ch.cards.first, knew: false);
      expect(state.levelOf(ch), ChapterLevel.learning);
      for (final c in ch.cards) {
        await state.answer(c, knew: true);
      }
      expect(state.levelOf(ch), ChapterLevel.mastered);
    });

    test('a test plans revision: mistakes first, then new cards', () async {
      final ch = state.deck!.chapters.first;
      await state.addExam(ch.subjectId, DateTime(2026, 10, 30), [ch.id]);
      final exam = state.upcomingExams.single;
      expect(state.daysUntil(exam), 7);
      expect(state.examReadiness(exam), 0);
      expect(state.examCardsLeft(exam), ch.cards.length);

      await state.answer(ch.cards[1], knew: true);
      await state.answer(ch.cards[2], knew: false);
      final queue = state.examQueue(exam);
      expect(queue.first, ch.cards[2], reason: 'the mistake comes first');
      expect(queue.last, ch.cards[1], reason: 'learnt cards come last');

      clock = DateTime(2026, 10, 31);
      expect(state.upcomingExams, isEmpty, reason: 'past tests drop off');
    });

    test('moving class clears school ticks and tests, keeps stars', () async {
      final p = state.current!..stars = 40;
      await state.setCovered(state.deck!.chapters.first.id, done: true);
      await state.addExam('science', DateTime(2026, 11, 1), ['x']);
      await state.editProfile(name: 'Diya S', classLevel: 9, avatar: 2);
      expect(p.name, 'Diya S');
      expect(p.classLevel, 9);
      expect(p.covered, isEmpty);
      expect(p.exams, isEmpty);
      expect(p.stars, 40);
      expect(state.deck!.classLevel, 9);
    });

    test('Ullu is dressed with what stars have unlocked', () async {
      expect(Wardrobe.nextUnlock(0)!.name, 'Sky blue');
      expect(Wardrobe.nextUnlock(12)!.name, 'Graduation cap');
      await state.dressOwl(colour: 'blue', hat: 'cap');
      final reloaded = Profile.fromJson(state.current!.toJson());
      expect(reloaded.owlColor, 'blue');
      expect(reloaded.owlHat, 'cap');
    });
  });

  test('another phone\'s choices fill in what this phone never chose', () {
    final mine = Profile(id: 'c1', name: 'Diya', classLevel: 8, avatar: 0)
      ..goalCards = 15;
    final theirs = Profile(id: 'c1', name: 'Diya', classLevel: 8, avatar: 0)
      ..goalCards = 45
      ..owlHat = 'crown'
      ..covered.add('c8-sci-01')
      ..exams.add(
        Exam(id: 'e1', subjectId: 'science', day: '2026-11-02', chapterIds: []),
      );
    mergeProgress(mine, theirs);
    expect(mine.goalCards, 15);
    expect(mine.owlHat, 'crown');
    expect(mine.covered, {'c8-sci-01'});
    expect(mine.exams.single.id, 'e1');
  });

  testWidgets('first launch: class and name, then straight to studying', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final decks = DeckRepository();
    final state = AppState(decks: decks, store: ProfileStore());
    final accounts = AccountState(service: DemoAccountService(decks: decks));
    await tester.runAsync(() async {
      await state.load();
      await accounts.load();
    });
    await tester.pumpWidget(
      SmartRevisionApp(
        state: state,
        accounts: accounts,
        speaker: SilentSpeaker(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Hi! I'm Ullu."), findsOneWidget);
    expect(find.text('Parent or teacher? Sign in here'), findsOneWidget);
    await tester.tap(find.text("Let's start"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class 8'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Diya');
    await tapAndWait(tester, find.text('Start learning'));

    expect(state.current?.name, 'Diya');
    expect(find.textContaining('Diya'), findsWidgets);
    expect(find.byTooltip('Switch student'), findsNothing);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('My daily goal'), findsOneWidget);
    expect(find.text('Ullu'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Parent or teacher? Sign in'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Parent or teacher? Sign in'), findsOneWidget);
  });
}
