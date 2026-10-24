import '../models/profile.dart';
import 'levels.dart';

/// What badges are judged on, worked out by the app state.
class BadgeFacts {
  const BadgeFacts({
    required this.profile,
    required this.streak,
    required this.learntBySubject,
    required this.subjectIds,
    required this.masteredChapters,
  });

  final Profile profile;
  final int streak;

  /// Learnt cards per subject id.
  final Map<String, int> learntBySubject;

  /// Subjects in the student's deck.
  final Set<String> subjectIds;

  /// Per subject: (chapters at 80% mastery or more, chapters in total).
  final Map<String, (int, int)> masteredChapters;

  List<QuizRecord> get quizzes => profile.quizzes;
  int get totalActivity => profile.activity.values.fold(0, (a, b) => a + b);
}

class BadgeDef {
  const BadgeDef(
    this.id,
    this.title,
    this.description,
    this.progress, {
    this.needsSubject,
  });

  final String id;
  final String title;
  final String description;

  /// (current, target). Earned once current reaches target.
  final (int, int) Function(BadgeFacts f) progress;

  /// Only shown when the deck has this subject.
  final String? needsSubject;

  bool availableFor(BadgeFacts f) =>
      needsSubject == null || f.subjectIds.contains(needsSubject);

  bool earned(BadgeFacts f) {
    final (cur, target) = progress(f);
    return cur >= target;
  }

  static (int, int) _count(int cur, int target) =>
      (cur.clamp(0, target), target);

  static (int, int) _any(bool done) => (done ? 1 : 0, 1);

  static final _firstQuiz = BadgeDef(
    'firstQuiz',
    'First Quiz',
    'Finish your first quiz',
    (f) => _count(f.quizzes.length, 1),
  );

  static final junior = <BadgeDef>[
    _firstQuiz,
    BadgeDef(
      'groupCounter',
      'Group Counter',
      'Learn 10 Maths cards',
      (f) => _count(f.learntBySubject['maths'] ?? 0, 10),
      needsSubject: 'maths',
    ),
    BadgeDef(
      'streak5',
      '5-day Streak',
      'Study 5 days in a row',
      (f) => _count(f.streak, 5),
    ),
    BadgeDef(
      'perfect5',
      'Perfect 5',
      'Get 5 out of 5 in a quiz',
      (f) => _any(f.quizzes.any((q) => q.total >= 5 && q.score == q.total)),
    ),
    BadgeDef(
      'wordWizard',
      'Word Wizard',
      'Learn 10 English cards',
      (f) => _count(f.learntBySubject['english'] ?? 0, 10),
      needsSubject: 'english',
    ),
    BadgeDef(
      'weekHero',
      'Week Hero',
      'Study 7 days in a row',
      (f) => _count(f.streak, 7),
    ),
    BadgeDef(
      'starCollector',
      'Star Collector',
      'Collect 100 stars',
      (f) => _count(f.profile.stars, 100),
    ),
    BadgeDef(
      'naturePal',
      'Nature Pal',
      'Learn 10 EVS cards',
      (f) => _count(f.learntBySubject['evs'] ?? 0, 10),
      needsSubject: 'evs',
    ),
    BadgeDef(
      'quizChamp',
      'Quiz Champ',
      'Finish 10 quizzes',
      (f) => _count(f.quizzes.length, 10),
    ),
  ];

  static final senior = <BadgeDef>[
    _firstQuiz,
    BadgeDef(
      'perfect10',
      'Perfect 10',
      'Get 10 out of 10 in a quiz',
      (f) => _any(f.quizzes.any((q) => q.total >= 10 && q.score == q.total)),
    ),
    BadgeDef(
      'streak7',
      '7-day Streak',
      'Study 7 days in a row',
      (f) => _count(f.streak, 7),
    ),
    BadgeDef(
      'cards500',
      '500 Cards',
      'Review 500 cards and questions',
      (f) => _count(f.totalActivity, 500),
    ),
    BadgeDef(
      'comeback',
      'Comeback',
      'Study again after a break of 3 days or more',
      (f) => _any(f.profile.events.contains('comeback')),
    ),
    BadgeDef(
      'earlyBird',
      'Early Bird',
      'Finish a session before 8 am',
      (f) => _any(f.profile.events.contains('earlyBird')),
    ),
    BadgeDef(
      'streak30',
      '30-day Streak',
      'Study 30 days in a row',
      (f) => _count(f.streak, 30),
    ),
    BadgeDef(
      'scienceAce',
      'Science Ace',
      'Reach 80% mastery in every Science chapter',
      (f) => f.masteredChapters['science'] ?? (0, 1),
      needsSubject: 'science',
    ),
    BadgeDef(
      'quizMarathon',
      'Quiz Marathon',
      'Finish 50 quizzes',
      (f) => _count(f.quizzes.length, 50),
    ),
    BadgeDef('allRounder', 'All-rounder', 'Take a quiz in every subject', (f) {
      final done = {
        for (final q in f.quizzes)
          if (q.subjectId != null) q.subjectId!,
      };
      return _count(
        f.subjectIds.where(done.contains).length,
        f.subjectIds.length,
      );
    }),
    BadgeDef(
      'speedster',
      'Speedster',
      '10 out of 10 in under 5 minutes',
      (f) => _any(
        f.quizzes.any(
          (q) => q.total >= 10 && q.score == q.total && q.seconds < 300,
        ),
      ),
    ),
    BadgeDef(
      'level10',
      'Level 10',
      'Reach Level 10',
      (f) => _count(Level.of(f.profile.xp).number, 10),
    ),
  ];

  static List<BadgeDef> forTier({required bool junior}) =>
      junior ? BadgeDef.junior : BadgeDef.senior;

  static BadgeDef? byId(String id) =>
      [...junior, ...senior].where((b) => b.id == id).firstOrNull;
}
