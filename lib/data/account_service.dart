import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/deck.dart';
import 'deck_repository.dart';

/// Everything that needs a server: SMS codes, parent approval and classes
/// shared between a teacher and their students.
///
/// [DemoAccountService] fakes it on the phone so every screen works before
/// the backend exists. A real implementation replaces it in main.dart.
abstract class AccountService {
  /// True while running without a server; screens say so where it matters.
  bool get isDemo;

  /// The code [verifyOtp] accepts in demo mode, shown as a hint.
  String? get demoOtp;

  /// Throws [AccountException] with a message for the user when the code
  /// can't be sent (bad number, too many tries, no internet).
  Future<void> sendOtp(String phone, {bool call = false});
  Future<bool> verifyOtp(String phone, String code);

  /// After the OTP: records who this number belongs to. Throws
  /// [AccountException] if the number is already set up with another role.
  Future<void> register(Role role, String phone);
  Future<void> signOut();

  /// Sends [name]'s request to the parent's phone number.
  Future<ApprovalRequest> requestApproval({
    required String name,
    required int classLevel,
    required int avatar,
    required String parentPhone,
  });

  /// The child id once the parent has said yes; null while waiting.
  Future<String?> approvedChildId(ApprovalRequest request);

  // ---- Parent ---------------------------------------------------------------

  /// Children saved for this parent, to restore profiles on a new phone.
  Future<List<ChildRecord>> loadChildren();
  Future<void> saveChild(ChildRecord child);

  /// Students who gave this parent's number and are waiting.
  Future<List<ApprovalRequest>> requestsForMe();

  /// Says yes and returns the new child's id.
  Future<String> approve(ApprovalRequest request);
  Future<void> decline(ApprovalRequest request);

  // ---- Student --------------------------------------------------------------

  /// [childId] joins the class with [code]; [classLevel] must match.
  Future<JoinResult> joinClass(String code, ChildRecord child);
  Future<List<StudentAssignment>> assignmentsFor(String childId);
  Future<void> submit(
    StudentAssignment a,
    String childId, {
    required int score,
    required int total,
    required List<Map<String, Object?>> answers,
  });

  /// The child's progress as saved on the server (Profile JSON), or null.
  Future<Map<String, dynamic>?> loadProgress(String childId);
  Future<void> saveProgress(String childId, Map<String, dynamic> profile);

  Future<List<ClassMembership>> membershipsFor(String childId);

  /// Tells the teacher the child was active and how they are doing.
  Future<void> reportProgress(
    String classId,
    String childId, {
    required double mastery,
  });

  // ---- Teacher --------------------------------------------------------------

  /// False until push reminders exist; the button is hidden.
  bool get canRemind;

  Future<List<TeacherClass>> loadClasses();
  Future<TeacherClass> createClass({
    required String school,
    required int classLevel,
    required String section,
    required String subjectId,
  });
  Future<void> addAssignment(TeacherClass c, Assignment a);
  Future<AssignmentResults> results(
    TeacherClass c,
    Assignment a,
    Chapter chapter,
  );
  Future<void> remind(TeacherClass c, Assignment a);
}

/// A failure worth showing the user as is.
class AccountException implements Exception {
  const AccountException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DemoAccountService implements AccountService {
  DemoAccountService({
    required this.decks,
    DateTime Function()? clock,
    this.approvalDelay = const Duration(seconds: 8),
  }) : now = clock ?? DateTime.now;

  static const _classesKey = 'demo.classes.v1';

  final DeckRepository decks;
  final DateTime Function() now;

  /// How long the pretend parent takes to tap the link.
  final Duration approvalDelay;

  @override
  bool get isDemo => true;

  @override
  String get demoOtp => '123456';

  @override
  Future<void> sendOtp(String phone, {bool call = false}) async {}

  @override
  Future<bool> verifyOtp(String phone, String code) async => code == demoOtp;

  @override
  Future<ApprovalRequest> requestApproval({
    required String name,
    required int classLevel,
    required int avatar,
    required String parentPhone,
  }) async => ApprovalRequest(
    id: '${now().microsecondsSinceEpoch}',
    name: name,
    classLevel: classLevel,
    avatar: avatar,
    parentPhone: parentPhone,
    sentAt: now(),
  );

  @override
  Future<String?> approvedChildId(ApprovalRequest request) async =>
      now().difference(request.sentAt) >= approvalDelay ? request.id : null;

  @override
  Future<void> register(Role role, String phone) async {}

  @override
  Future<void> signOut() async {}

  // Children live only on the phone in demo mode.
  @override
  Future<List<ChildRecord>> loadChildren() async => const [];

  @override
  Future<void> saveChild(ChildRecord child) async {}

  @override
  Future<List<ApprovalRequest>> requestsForMe() async => const [];

  @override
  Future<String> approve(ApprovalRequest request) async => request.id;

  @override
  Future<void> decline(ApprovalRequest request) async {}

  /// The sample class's code joins; anything else is wrong.
  @override
  Future<JoinResult> joinClass(String code, ChildRecord child) async {
    final c = (await loadClasses()).where((c) => c.joinCode == code);
    if (c.isEmpty) return JoinResult.badCode;
    if (c.first.classLevel != child.classLevel) return JoinResult.wrongClass;
    return JoinResult.joined;
  }

  @override
  Future<List<StudentAssignment>> assignmentsFor(String childId) async =>
      const [];

  @override
  Future<void> submit(
    StudentAssignment a,
    String childId, {
    required int score,
    required int total,
    required List<Map<String, Object?>> answers,
  }) async {}

  @override
  Future<Map<String, dynamic>?> loadProgress(String childId) async => null;

  @override
  Future<void> saveProgress(
    String childId,
    Map<String, dynamic> profile,
  ) async {}

  @override
  Future<List<ClassMembership>> membershipsFor(String childId) async =>
      const [];

  @override
  Future<void> reportProgress(
    String classId,
    String childId, {
    required double mastery,
  }) async {}

  @override
  bool get canRemind => true;

  // ---- Classes ------------------------------------------------------------

  @override
  Future<List<TeacherClass>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_classesKey);
    if (raw != null) {
      return [
        for (final c in jsonDecode(raw) as List)
          TeacherClass.fromJson((c as Map).cast<String, dynamic>()),
      ];
    }
    final classes = [await _sampleClass()];
    await _save(classes);
    return classes;
  }

  Future<void> _save(List<TeacherClass> classes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _classesKey,
      jsonEncode([for (final c in classes) c.toJson()]),
    );
  }

  /// A filled-in class so the teacher screens have something to show.
  Future<TeacherClass> _sampleClass() async {
    final t = now();
    final deck = await decks.load(8);
    final science = deck?.subjects.where((s) => s.id == 'science').firstOrNull;
    final chapters = science?.chapters ?? const <Chapter>[];
    const names = [
      ('Aisha Khan', 0, 0.92),
      ('Arjun Nair', 1, 0.74),
      ('Diya Sharma', 0, 0.88),
      ('Kabir Singh', 0, 0.81),
      ('Meera Iyer', 3, 0.52),
      ('Rohan Das', 1, 0.67),
      ('Sara Thomas', 0, 0.95),
      ('Vivaan Rao', 2, 0.59),
      ('Ananya Bose', 0, 0.83),
      ('Farhan Ali', 5, 0.44),
      ('Pooja Patel', 1, 0.71),
    ];
    return TeacherClass(
      id: 'sample',
      school: 'Sample School',
      subjectId: 'science',
      classLevel: 8,
      section: 'B',
      joinCode: 'K7M2QX',
      size: 14,
      students: [
        for (final (name, daysAgo, mastery) in names)
          ClassStudent(
            name: name,
            lastActive: t.subtract(Duration(days: daysAgo, hours: 2)),
            mastery: mastery,
          ),
        const ClassStudent(name: 'Ishaan Gupta', awaitingParent: true),
      ],
      assignments: [
        if (chapters.length > 1)
          Assignment(
            id: 'sample-deck',
            kind: AssignmentKind.deck,
            subjectId: 'science',
            chapterId: chapters[1].id,
            due: DateTime(t.year, t.month, t.day + 3),
            createdAt: t.subtract(const Duration(hours: 5)),
          ),
        if (chapters.isNotEmpty)
          Assignment(
            id: 'sample-quiz',
            kind: AssignmentKind.quiz,
            subjectId: 'science',
            chapterId: chapters[0].id,
            due: DateTime(t.year, t.month, t.day),
            createdAt: t.subtract(const Duration(days: 1)),
          ),
      ],
    );
  }

  @override
  Future<TeacherClass> createClass({
    required String school,
    required int classLevel,
    required String section,
    required String subjectId,
  }) async {
    final rnd = Random(now().microsecondsSinceEpoch);
    // No 0/O or 1/I so the code reads aloud cleanly.
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final c = TeacherClass(
      id: '${now().microsecondsSinceEpoch}',
      school: school,
      subjectId: subjectId,
      classLevel: classLevel,
      section: section,
      joinCode: [
        for (var i = 0; i < 6; i++) letters[rnd.nextInt(letters.length)],
      ].join(),
      size: 0,
      students: [],
      assignments: [],
    );
    final classes = await loadClasses();
    await _save([...classes, c]);
    return c;
  }

  @override
  Future<void> addAssignment(TeacherClass c, Assignment a) async {
    c.assignments.insert(0, a);
    final classes = await loadClasses();
    await _save([for (final x in classes) x.id == c.id ? c : x]);
  }

  /// Made-up but steady results: the same assignment always gives the same
  /// numbers, and more students finish as time passes.
  @override
  Future<AssignmentResults> results(
    TeacherClass c,
    Assignment a,
    Chapter chapter,
  ) async {
    final rnd = Random(a.id.hashCode);
    final students = c.approved;
    final elapsed = now().difference(a.createdAt);
    final share = min(0.8, 0.1 + elapsed.inMinutes / (24 * 60) * 0.7);

    final ids = a.cardIds?.toSet();
    final cards = chapter.cards
        .where((c) => ids == null || ids.contains(c.id))
        .take(10)
        .toList();
    final total = cards.length;
    final difficulty = [for (final _ in cards) 0.55 + rnd.nextDouble() * 0.45];
    final right = List.filled(cards.length, 0);

    final done = <StudentResult>[];
    final notYet = <ClassStudent>[];
    for (final s in students) {
      if (rnd.nextDouble() >= share) {
        notYet.add(s);
        continue;
      }
      var score = 0;
      for (var i = 0; i < cards.length; i++) {
        final p = (s.mastery ?? 0.6) * difficulty[i] + 0.15;
        if (rnd.nextDouble() < p) {
          score++;
          right[i]++;
        }
      }
      done.add(
        StudentResult(
          student: s,
          finishedAt: a.createdAt.add(elapsed * rnd.nextDouble()),
          score: score,
          total: total,
        ),
      );
    }
    done.sort((x, y) => y.score.compareTo(x.score));

    final questions = a.kind == AssignmentKind.deck || done.isEmpty
        ? <QuestionStat>[]
        : [
            for (var i = 0; i < cards.length; i++)
              QuestionStat(
                cardId: cards[i].id,
                number: i + 1,
                text: cards[i].front,
                rightShare: right[i] / done.length,
                commonWrong: cards[i].wrong.isEmpty
                    ? null
                    : '${'BCD'[rnd.nextInt(3)]} · ${cards[i].wrong.first}',
              ),
          ];
    questions.sort((x, y) => x.rightShare.compareTo(y.rightShare));
    return AssignmentResults(done: done, notYet: notYet, questions: questions);
  }

  @override
  Future<void> remind(TeacherClass c, Assignment a) async {}
}
