import 'dart:convert';
import 'dart:math';

import '../models/profile.dart';
import 'scheduler.dart';

/// Folds [other] (the same child's progress from another phone) into [into]
/// so nothing studied on either phone is lost. Name, class and avatar stay
/// as [into] has them; those are edited on the child record.
///
/// Returns true if [into] changed.
bool mergeProgress(Profile into, Profile other) {
  final before = jsonEncode(into.toJson());

  // Each card: whichever phone reviewed it last.
  for (final e in other.cards.entries) {
    final mine = into.cards[e.key];
    if (mine == null || _later(e.value, mine)) into.cards[e.key] = e.value;
  }

  // Totals only ever grow.
  into.stars = max(into.stars, other.stars);
  into.xp = max(into.xp, other.xp);

  // The streak belongs to whichever phone studied most recently.
  final day = _compare(other.lastStudyDay, into.lastStudyDay);
  if (day > 0) {
    into.lastStudyDay = other.lastStudyDay;
    into.streak = other.streak;
  } else if (day == 0) {
    into.streak = max(into.streak, other.streak);
  }

  into.studyDays.addAll(other.studyDays);
  into.events.addAll(other.events);
  _maxEach(into.activity, other.activity);
  _maxEach(into.seconds, other.seconds);

  // Badges: earned on either; keep the earlier date.
  for (final e in other.badges.entries) {
    final mine = into.badges[e.key];
    if (mine == null ||
        mine.isEmpty ||
        (e.value.isNotEmpty && e.value.compareTo(mine) < 0)) {
      into.badges[e.key] = e.value;
    }
  }

  // Quizzes: everything from both, once each, oldest first.
  String key(QuizRecord q) =>
      '${q.at.toIso8601String()}|${q.chapterId}|${q.score}/${q.total}';
  final seen = {for (final q in into.quizzes) key(q)};
  for (final q in other.quizzes) {
    if (seen.add(key(q))) into.quizzes.add(q);
  }
  into.quizzes.sort((a, b) => a.at.compareTo(b.at));

  final goal = _compare(other.goalDay, into.goalDay);
  if (goal > 0) {
    into.goalDay = other.goalDay;
    into.goalDone = other.goalDone;
  } else if (goal == 0) {
    into.goalDone = max(into.goalDone, other.goalDone);
  }

  final theirs = other.lastStudiedAt;
  final mine = into.lastStudiedAt;
  if (theirs != null && (mine == null || theirs.isAfter(mine))) {
    into.lastStudiedAt = theirs;
    into.lastSubjectId = other.lastSubjectId;
    into.lastChapterId = other.lastChapterId;
  }

  return jsonEncode(into.toJson()) != before;
}

bool _later(CardState a, CardState b) {
  final ta = a.at;
  final tb = b.at;
  if (ta == null) return false;
  if (tb == null) return true;
  return ta.isAfter(tb);
}

/// yyyy-mm-dd strings sort by date; null is oldest.
int _compare(String? a, String? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

void _maxEach(Map<String, int> into, Map<String, int> other) {
  for (final e in other.entries) {
    into[e.key] = max(into[e.key] ?? 0, e.value);
  }
}
