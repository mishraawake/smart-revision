import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_revision/app.dart';
import 'package:smart_revision/data/account_service.dart';
import 'package:smart_revision/data/deck_repository.dart';
import 'package:smart_revision/data/profile_store.dart';
import 'package:smart_revision/data/speaker.dart';
import 'package:smart_revision/models/account.dart';
import 'package:smart_revision/state/account_state.dart';
import 'package:smart_revision/state/app_state.dart';
import 'package:smart_revision/widgets/common.dart';

Future<(AppState, SilentSpeaker)> pumpApp(
  WidgetTester tester, {
  Role role = Role.parent,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Signed in already: a parent lands on "Who's studying?".
  SharedPreferences.setMockInitialValues({
    'account.v1': jsonEncode(Account(role: role).toJson()),
  });
  final decks = DeckRepository();
  final state = AppState(decks: decks, store: ProfileStore());
  final speaker = SilentSpeaker();
  final accounts = AccountState(
    service: DemoAccountService(decks: decks),
    speaker: speaker,
  );
  await tester.runAsync(() async {
    await state.load();
    await accounts.load();
  });
  await tester.pumpWidget(
    SmartRevisionApp(state: state, accounts: accounts, speaker: speaker),
  );
  await tester.pumpAndSettle();
  return (state, speaker);
}

/// Taps, then lets real async work (prefs, asset loading) finish.
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

Future<void> addStudent(
  WidgetTester tester,
  String name,
  int classLevel,
) async {
  await tester.tap(find.textContaining(RegExp('Add (child|a student)')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Class $classLevel').last);
  await tester.pumpAndSettle();
  await tapAndWait(tester, find.text('Add'));
}

Future<void> answerCards(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text(i.isEven ? 'Knew it' : "Didn't know"));
  }
}

void main() {
  testWidgets('junior: add a child, review, see the celebration', (
    tester,
  ) async {
    final (state, speaker) = await pumpApp(tester);
    expect(find.text("Who's studying?"), findsOneWidget);

    await addStudent(tester, 'Aarav', 2);
    await tapAndWait(tester, find.text('Aarav').first);
    expect(find.text('Hi Aarav!'), findsOneWidget);
    expect(find.text('10 cards waiting'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is ReadAloudButton && w.text.startsWith('Hi Aarav'),
      ),
    );
    expect(speaker.spoken.single, contains('10 cards waiting'));

    await tester.tap(find.text("Start today's review"));
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 10 · Maths'), findsOneWidget);

    await answerCards(tester, 10);
    expect(find.text('Well done, Aarav!'), findsOneWidget);
    expect(find.text('+13 stars'), findsOneWidget);
    expect(find.text('5 knew'), findsOneWidget);
    expect(find.text('5 again'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('10/10'), findsOneWidget);
    expect(find.text('All done for today!'), findsOneWidget);
    expect(state.current!.stars, 13);
  });

  testWidgets('senior: review shows scheduling captions and a summary', (
    tester,
  ) async {
    await pumpApp(tester);
    await addStudent(tester, 'Diya', 8);
    await tapAndWait(tester, find.text('Diya').first);

    expect(find.text("Start today's review · 29 due"), findsOneWidget);
    await tester.tap(find.text("Start today's review · 29 due"));
    await tester.pumpAndSettle();
    expect(find.text('1/15'), findsOneWidget);

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    expect(find.text('Next tomorrow'), findsOneWidget);
    expect(find.text('Again in 10 min'), findsOneWidget);
    await tapAndWait(tester, find.text('Knew it'));

    await answerCards(tester, 14);
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('Practise the 7 I missed'), findsOneWidget);

    await tester.tap(find.text('Back to Today'));
    await tester.pumpAndSettle();
    expect(find.text("Start today's review · 14 due"), findsOneWidget);
  });
}
