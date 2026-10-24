import '../models/deck.dart';
import '../models/profile.dart';
import '../state/app_state.dart' show dayKey;

/// What a parent sees about one child: this week's minutes, chapters
/// mastered and where recall is weakest.
class ChildInsights {
  ChildInsights(this.profile, this.deck, {required this.now});

  /// A chapter counts as mastered from this mastery up.
  static const masteredFrom = 0.8;

  /// Chapters need this many cards seen before their recall means much.
  static const minSeen = 3;

  final Profile profile;

  /// Null when the child's class has no content yet.
  final ClassDeck? deck;
  final DateTime now;

  int get minutesGoal => profile.isJunior ? 10 : 20;

  DateTime get weekStart {
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  /// Minutes on each day Monday to Sunday; null for days still to come.
  List<int?> get weekMinutes => [
    for (var i = 0; i < 7; i++)
      () {
        final day = weekStart.add(Duration(days: i));
        if (day.isAfter(now)) return null;
        return ((profile.seconds[dayKey(day)] ?? 0) / 60).round();
      }(),
  ];

  int get weekTotal => weekMinutes.whereType<int>().fold(0, (a, b) => a + b);

  /// Longest run of study days in a row, ever.
  int get bestStreak {
    final days = profile.studyDays.map(DateTime.parse).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && d.difference(prev).inDays == 1 ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best > profile.streak ? best : profile.streak;
  }

  QuizRecord? _bestQuiz(String chapterId) {
    QuizRecord? best;
    for (final q in profile.quizzes) {
      if (q.chapterId != chapterId) continue;
      if (best == null || q.accuracy > best.accuracy) best = q;
    }
    return best;
  }

  /// Same measure as the student's chapter list: learnt share of cards,
  /// averaged with the best quiz score once there is one.
  double mastery(Chapter ch) {
    if (ch.cards.isEmpty) return 0;
    final learnt =
        ch.cards.where((c) => profile.cards[c.id]?.learnt ?? false).length /
        ch.cards.length;
    final best = _bestQuiz(ch.id);
    return best == null ? learnt : (learnt + best.accuracy) / 2;
  }

  int get chapterCount => deck?.chapters.length ?? 0;

  int get mastered =>
      deck?.chapters.where((c) => mastery(c) >= masteredFrom).length ?? 0;

  /// Of the cards seen, the share currently remembered.
  double? recall(Chapter ch) {
    final seen = ch.cards.where((c) => profile.cards.containsKey(c.id));
    if (seen.length < minSeen) return null;
    return seen.where((c) => profile.cards[c.id]!.learnt).length / seen.length;
  }

  /// Up to three started chapters with the lowest recall below mastery.
  List<(Chapter, double)> get needsPractice {
    final list = [
      for (final ch in deck?.chapters ?? const <Chapter>[])
        if (recall(ch) case final r? when r < masteredFrom) (ch, r),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return list.take(3).toList();
  }

  /// Newest first.
  List<QuizRecord> get recentQuizzes =>
      profile.quizzes.reversed.take(3).toList();

  Chapter? chapter(String? id) =>
      deck?.chapters.where((c) => c.id == id).firstOrNull;

  Subject? subject(String? id) =>
      deck?.subjects.where((s) => s.id == id).firstOrNull;
}
