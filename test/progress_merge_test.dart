import 'package:flutter_test/flutter_test.dart';
import 'package:smart_revision/logic/progress_merge.dart';
import 'package:smart_revision/logic/scheduler.dart';
import 'package:smart_revision/models/profile.dart';

Profile child({String name = 'Diya'}) =>
    Profile(id: 'c1', name: name, classLevel: 8, avatar: 0);

CardState card(int box, DateTime? at) =>
    CardState(box: box, due: DateTime(2026, 11, 1), at: at);

void main() {
  final mon = DateTime(2026, 10, 19, 17);
  final tue = DateTime(2026, 10, 20, 17);

  test('each card keeps the most recent review from either phone', () {
    final mine = child()
      ..cards['a'] = card(2, tue)
      ..cards['b'] = card(1, mon)
      ..cards['old'] = card(3, null);
    final theirs = child()
      ..cards['a'] = card(0, mon)
      ..cards['b'] = card(0, tue)
      ..cards['old'] = card(1, mon)
      ..cards['new'] = card(1, mon);

    expect(mergeProgress(mine, theirs), isTrue);
    expect(mine.cards['a']!.box, 2, reason: 'mine was reviewed later');
    expect(mine.cards['b']!.box, 0, reason: 'theirs was reviewed later');
    expect(mine.cards['old']!.box, 1, reason: 'a dated review beats none');
    expect(mine.cards['new']!.box, 1, reason: 'cards only they had come in');
  });

  test('totals grow, days and badges add up, quizzes appear once', () {
    final quiz = QuizRecord(
      subjectId: 'science',
      chapterId: 'c8-sci-01',
      at: mon,
      score: 7,
      total: 10,
      seconds: 90,
    );
    final mine = child()
      ..stars = 40
      ..xp = 10
      ..studyDays.add('2026-10-19')
      ..activity['2026-10-19'] = 12
      ..badges['first'] = '2026-10-19'
      ..quizzes.add(quiz);
    final theirs = child()
      ..stars = 25
      ..xp = 30
      ..studyDays.add('2026-10-20')
      ..activity['2026-10-19'] = 5
      ..activity['2026-10-20'] = 8
      ..badges['first'] = '2026-10-18'
      ..badges['streak3'] = '2026-10-20'
      ..quizzes.addAll([
        quiz,
        QuizRecord(
          subjectId: 'maths',
          chapterId: 'c8-maths-01',
          at: tue,
          score: 4,
          total: 5,
          seconds: 60,
        ),
      ]);

    mergeProgress(mine, theirs);
    expect(mine.stars, 40);
    expect(mine.xp, 30);
    expect(mine.studyDays, {'2026-10-19', '2026-10-20'});
    expect(mine.activity, {'2026-10-19': 12, '2026-10-20': 8});
    expect(mine.badges, {'first': '2026-10-18', 'streak3': '2026-10-20'});
    expect(mine.quizzes.map((q) => q.chapterId), ['c8-sci-01', 'c8-maths-01']);
  });

  test('the streak comes from whichever phone studied last', () {
    final mine = child()
      ..lastStudyDay = '2026-10-19'
      ..streak = 9;
    final theirs = child()
      ..lastStudyDay = '2026-10-20'
      ..streak = 2
      ..lastStudiedAt = tue
      ..lastChapterId = 'c8-sci-02';

    mergeProgress(mine, theirs);
    expect(mine.streak, 2);
    expect(mine.lastStudyDay, '2026-10-20');
    expect(mine.lastChapterId, 'c8-sci-02');
  });

  test('name and class stay as this phone has them; no change, no save', () {
    final mine = child(name: 'Diya S')..cards['a'] = card(1, tue);
    final theirs = child(name: 'Diya')..cards['a'] = card(1, tue);
    expect(mergeProgress(mine, theirs), isFalse);
    expect(mine.name, 'Diya S');
  });

  test('grading records when a card was reviewed', () {
    final s = Scheduler.grade(null, knew: true, now: tue);
    expect(s.at, tue);
    expect(CardState.fromJson(s.toJson()).at, tue);
    expect(CardState.fromJson({'box': 1, 'due': '2026-10-21'}).at, isNull);
  });
}
