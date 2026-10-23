import '../logic/scheduler.dart';

/// One student on this phone. No passwords; everything stays on the device.
class Profile {
  Profile({
    required this.id,
    required this.name,
    required this.classLevel,
    required this.avatar,
    this.stars = 0,
    this.streak = 0,
    this.lastStudyDay,
    Set<String>? studyDays,
    Map<String, CardState>? cards,
    Set<String>? badges,
    this.goalDay,
    this.goalDone = 0,
    this.lastSubjectId,
    this.lastChapterId,
    this.lastStudiedAt,
  }) : studyDays = studyDays ?? {},
       cards = cards ?? {},
       badges = badges ?? {};

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    name: j['name'] as String,
    classLevel: j['classLevel'] as int,
    avatar: j['avatar'] as int,
    stars: j['stars'] as int? ?? 0,
    streak: j['streak'] as int? ?? 0,
    lastStudyDay: j['lastStudyDay'] as String?,
    studyDays: {...?(j['studyDays'] as List?)?.cast<String>()},
    cards: {
      for (final e in ((j['cards'] as Map?) ?? {}).entries)
        e.key as String: CardState.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        ),
    },
    badges: {...?(j['badges'] as List?)?.cast<String>()},
    goalDay: j['goalDay'] as String?,
    goalDone: j['goalDone'] as int? ?? 0,
    lastSubjectId: j['lastSubjectId'] as String?,
    lastChapterId: j['lastChapterId'] as String?,
    lastStudiedAt: j['lastStudiedAt'] == null
        ? null
        : DateTime.parse(j['lastStudiedAt'] as String),
  );

  final String id;
  String name;
  int classLevel;

  /// Index into the avatar palette.
  int avatar;

  int stars;
  int streak;

  /// yyyy-mm-dd of the last day a review session was finished.
  String? lastStudyDay;
  final Set<String> studyDays;

  /// Scheduling state per card id. Cards without an entry are new.
  final Map<String, CardState> cards;
  final Set<String> badges;

  /// Cards reviewed on [goalDay] count towards the daily goal ring.
  String? goalDay;
  int goalDone;

  String? lastSubjectId;
  String? lastChapterId;
  DateTime? lastStudiedAt;

  bool get isJunior => classLevel <= 5;
  int get dailyGoal => isJunior ? 10 : 30;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'classLevel': classLevel,
    'avatar': avatar,
    'stars': stars,
    'streak': streak,
    'lastStudyDay': lastStudyDay,
    'studyDays': studyDays.toList(),
    'cards': {for (final e in cards.entries) e.key: e.value.toJson()},
    'badges': badges.toList(),
    'goalDay': goalDay,
    'goalDone': goalDone,
    'lastSubjectId': lastSubjectId,
    'lastChapterId': lastChapterId,
    'lastStudiedAt': lastStudiedAt?.toIso8601String(),
  };
}
