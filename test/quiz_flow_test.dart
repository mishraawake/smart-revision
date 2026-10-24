import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_revision/data/deck_repository.dart';
import 'package:smart_revision/data/profile_store.dart';
import 'package:smart_revision/data/speaker.dart';
import 'package:smart_revision/logic/quiz.dart';
import 'package:smart_revision/models/deck.dart';
import 'package:smart_revision/screens/quiz/quiz_screen.dart';
import 'package:smart_revision/state/app_state.dart';
import 'package:smart_revision/theme/app_theme.dart';
import 'package:smart_revision/widgets/common.dart';

Flashcard card(String id, String front, String back, {String? explain}) =>
    Flashcard(
      id: id,
      subjectId: 'maths',
      chapterId: 'c2-maths-02',
      front: front,
      back: back,
      explain: explain,
    );

/// One question of each type, in a fixed order so taps are predictable.
List<QuizQuestion> fixedQuestions({required bool junior}) {
  final a = card(
    'q1',
    'How many stars in all?',
    '12',
    explain: '4 + 4 + 4 = 12',
  );
  final b = card('q2', 'Is 3 groups of 4 the same as 4 + 4 + 4?', 'Yes');
  final c = card('q3', 'Count in 2s: 2, 4, 6, … next?', 'eight');
  return [
    McqQuestion(card: a, options: ['7', '10', '12', '16'], correctIndex: 2),
    TrueFalseQuestion(
      card: b,
      statement: '4 + 4 + 4 is the same as 3 groups of 4.',
      isTrue: true,
    ),
    FillBlankQuestion(
      card: c,
      sentence: 'Count in twos: two, four, six, ___, ten.',
      answer: 'eight',
      tiles: junior ? ['seven', 'eight', 'nine', 'twelve'] : const [],
      typed: !junior,
    ),
    MatchQuestion(
      pairs: const [
        MatchPair('2 groups of 3', '6'),
        MatchPair('2 groups of 5', '10'),
        MatchPair('4 groups of 2', '8'),
      ],
      rightOrder: [2, 0, 1],
    ),
  ];
}

Future<AppState> pumpQuiz(
  WidgetTester tester, {
  required int classLevel,
  required List<QuizQuestion> questions,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final state = AppState(decks: DeckRepository(), store: ProfileStore());
  await tester.runAsync(() async {
    await state.load();
    await state.addProfile('Kid', classLevel);
    await state.select(state.profiles.single);
  });
  final junior = classLevel <= 5;
  final ch = state.deck!.chapters.first;
  await tester.pumpWidget(
    SpeakerScope(
      speaker: SilentSpeaker(),
      child: AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(junior ? Tier.junior : Tier.senior),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          QuizScreen(questions: questions, chapter: ch),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return state;
}

Future<void> tapAndWait(WidgetTester tester, Finder f) async {
  await tester.runAsync(() async {
    await tester.tap(f);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) async {
  final label = find.text('Next').evaluate().isEmpty ? 'See results' : 'Next';
  await tapAndWait(tester, find.text(label));
}

void main() {
  testWidgets('Junior plays all four question types to the results', (
    tester,
  ) async {
    final state = await pumpQuiz(
      tester,
      classLevel: 2,
      questions: fixedQuestions(junior: true),
    );

    // Multiple choice: pick, check, feedback.
    expect(find.text('Question 1 of 4'), findsOneWidget);
    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Yes! Right!'), findsOneWidget);
    expect(find.text('+1 star'), findsOneWidget);
    await next(tester);

    // True or false answers on tap, no Check needed. Answer wrong.
    expect(find.text('True or false?'), findsOneWidget);
    await tester.tap(find.text('False'));
    await tester.pumpAndSettle();
    expect(find.text('Almost!'), findsOneWidget);
    expect(find.text('The answer is True'), findsOneWidget);
    expect(find.text("We'll try this one again later."), findsOneWidget);
    await next(tester);

    // Fill the gap with a tile.
    await tester.tap(find.text('eight'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Yes! Right!'), findsOneWidget);
    await next(tester);

    // Match: one wrong tap is a slip but still counts as right.
    expect(find.text('0 of 3 pairs matched'), findsOneWidget);
    await tester.tap(find.text('2 groups of 3'));
    await tester.pump();
    await tester.tap(find.text('10'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('2 groups of 3'));
    await tester.pump();
    await tester.tap(find.text('6'));
    await tester.pump();
    expect(find.text('1 of 3 pairs matched'), findsOneWidget);
    for (final (l, r) in [('2 groups of 5', '10'), ('4 groups of 2', '8')]) {
      await tester.tap(find.text(l));
      await tester.pump();
      await tester.tap(find.text(r));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Yes! Right!'), findsOneWidget);
    await next(tester);

    // Results.
    expect(find.text('Great try, Kid!'), findsOneWidget);
    expect(find.text('3 out of 4'), findsOneWidget);
    expect(find.text('Get 4 out of 4 for the third star'), findsOneWidget);
    expect(state.current!.quizzes, hasLength(1));
    expect(state.current!.xp, 30);
  });

  testWidgets('Senior types answers, skips and sees mistakes', (tester) async {
    final state = await pumpQuiz(
      tester,
      classLevel: 8,
      questions: fixedQuestions(junior: false),
    );

    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('Choose one answer'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('Added to your review deck'), findsOneWidget);
    await next(tester);

    await tester.tap(find.text('True'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    await next(tester);

    // A small spelling slip still counts, marked close.
    await tester.enterText(find.byType(TextField), 'Eigth');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Close! It is spelt "eight".'), findsOneWidget);
    await next(tester);

    for (final (l, r) in [
      ('2 groups of 3', '6'),
      ('2 groups of 5', '10'),
      ('4 groups of 2', '8'),
    ]) {
      await tester.tap(find.text(l));
      await tester.pump();
      await tester.tap(find.text(r));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await next(tester);

    expect(find.textContaining('3/4'), findsWidgets);
    expect(find.text('Mistakes to review · 1'), findsOneWidget);
    expect(find.text('Review 1 mistake'), findsOneWidget);
    expect(
      state.stateOf(fixedQuestions(junior: false)[0].card!)!.learnt,
      isFalse,
    );
  });
}
