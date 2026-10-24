/// XP rules and levels from the Phase 2 design.
abstract final class Xp {
  static const perRightAnswer = 10;

  /// Taken off a right answer when the first-letter hint was used.
  static const hintCost = 5;
  static const threeStarBonus = 20;
  static const dailyGoalBonus = 5;
}

/// Quiz stars: 3 for 90% or better, 2 for 70%, 1 for 50%.
int quizStars(int score, int total) {
  if (total == 0) return 0;
  final p = score / total;
  return p >= 0.9
      ? 3
      : p >= 0.7
      ? 2
      : p >= 0.5
      ? 1
      : 0;
}

/// Smallest score that earns [stars] in a quiz of [total] questions.
int scoreForStars(int stars, int total) {
  const cut = {1: 0.5, 2: 0.7, 3: 0.9};
  return (cut[stars]! * total - 1e-9).ceil();
}

class Level {
  const Level(this.number, this.start, this.next);

  /// Level number, from 1.
  final int number;

  /// Total XP at which this level starts.
  final int start;

  /// Total XP at which the next level starts.
  final int next;

  int get span => next - start;
  String get name => levelName(number);
  String get nextName => levelName(number + 1);

  /// Level n needs 50 × n XP to finish, so early levels come quickly.
  static Level of(int xp) {
    var n = 1;
    var start = 0;
    while (xp >= start + 50 * n) {
      start += 50 * n;
      n++;
    }
    return Level(n, start, start + 50 * n);
  }
}

String levelName(int n) => const [
  'Beginner',
  'Learner',
  'Bright Spark',
  'Super Learner',
  'Star Student',
  'Thinker',
  'Explorer',
  'Scholar',
  'Expert',
  'Master',
][(n - 1).clamp(0, 9)];
