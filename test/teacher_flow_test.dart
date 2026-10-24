import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_revision/models/account.dart';

import 'review_flow_test.dart' show pumpApp, tapAndWait;

void main() {
  testWidgets('teacher sets a quiz, then opens results and remind', (
    tester,
  ) async {
    await pumpApp(tester, role: Role.teacher);
    expect(find.text('Class 8 · Section B'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);

    await tapAndWait(tester, find.text('New'));
    expect(find.text('New assignment'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    await tester.tap(find.text('Ch 2'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('Assign quiz to 11 students'));
    expect(find.text('New assignment'), findsNothing);
    expect(find.textContaining('Quiz · Science Ch 2'), findsOneWidget);

    // The sample quiz set yesterday has results to show.
    await tester.ensureVisible(find.textContaining('Quiz · Science Ch 1'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.textContaining('Quiz · Science Ch 1').first);
    expect(find.text('Weakest questions'), findsOneWidget);
    expect(find.text('Average score'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Remind the'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapAndWait(tester, find.textContaining('Remind the'));
    expect(find.text('Reminder sent'), findsOneWidget);
  });

  testWidgets('teacher adds a class and gets a join code', (tester) async {
    await pumpApp(tester, role: Role.teacher);
    await tapAndWait(tester, find.byTooltip('Add a class'));
    await tester.enterText(find.byType(TextField), 'Kendriya Vidyalaya');
    await tester.tap(find.bySemanticsLabel('Class 7'));
    await tester.tap(find.bySemanticsLabel('Section C'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('Maths'));
    await tapAndWait(tester, find.text('Create class'));
    expect(find.text('Class 7 · Section C'), findsOneWidget);
    expect(
      find.text(
        'Nothing set yet. Tap New to assign a chapter deck or '
        'a quiz.',
      ),
      findsOneWidget,
    );
  });
}
