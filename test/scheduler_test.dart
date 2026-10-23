import 'package:flutter_test/flutter_test.dart';
import 'package:smart_revision/logic/scheduler.dart';

void main() {
  final now = DateTime(2026, 10, 23, 18);

  test('a new card known once is due tomorrow and counts as learnt', () {
    final s = Scheduler.grade(null, knew: true, now: now);
    expect(s.box, 1);
    expect(s.learnt, isTrue);
    expect(s.due, now.add(const Duration(days: 1)));
  });

  test('knowing a card again pushes it further out', () {
    final s = Scheduler.grade(
      CardState(box: 1, due: now),
      knew: true,
      now: now,
    );
    expect(s.box, 2);
    expect(s.due, now.add(const Duration(days: 4)));
  });

  test("didn't know resets the card and brings it back in 10 minutes", () {
    final s = Scheduler.grade(
      CardState(box: 3, due: now),
      knew: false,
      now: now,
    );
    expect(s.box, 0);
    expect(s.learnt, isFalse);
    expect(s.due, now.add(const Duration(minutes: 10)));
  });

  test('the top box keeps the longest interval', () {
    final top = Scheduler.intervals.length;
    final s = Scheduler.grade(
      CardState(box: top, due: now),
      knew: true,
      now: now,
    );
    expect(s.box, top);
    expect(s.due, now.add(Scheduler.intervals.last));
  });

  test('describeInterval', () {
    expect(describeInterval(const Duration(days: 1)), 'tomorrow');
    expect(describeInterval(const Duration(days: 4)), 'in 4 days');
    expect(describeInterval(const Duration(minutes: 10)), 'in 10 min');
  });
}
