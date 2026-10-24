/// Who signed in on this phone. Children don't sign in themselves: a parent
/// adds them, or a Class 6–10 student signs up and a parent approves.
enum Role { parent, teacher, student }

class Account {
  Account({required this.role, this.phone, this.consentAt});

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    role: Role.values.byName(j['role'] as String),
    phone: j['phone'] as String?,
    consentAt: j['consentAt'] == null
        ? null
        : DateTime.parse(j['consentAt'] as String),
  );

  final Role role;

  /// 10-digit Indian mobile number without +91. Null for profiles made
  /// before sign-in existed, and for students (their parent's number is on
  /// the approval request).
  final String? phone;

  /// When the parent agreed to the terms and to storing progress.
  final DateTime? consentAt;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'phone': phone,
    'consentAt': consentAt?.toIso8601String(),
  };
}

/// A Class 6–10 student waiting for a parent to say yes.
class ApprovalRequest {
  ApprovalRequest({
    required this.id,
    required this.name,
    required this.classLevel,
    required this.avatar,
    required this.parentPhone,
    required this.sentAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> j) => ApprovalRequest(
    id: j['id'] as String,
    name: j['name'] as String,
    classLevel: j['classLevel'] as int,
    avatar: j['avatar'] as int,
    parentPhone: j['parentPhone'] as String,
    sentAt: DateTime.parse(j['sentAt'] as String),
  );

  /// Approval links stop working after this long.
  static const validFor = Duration(hours: 48);

  final String id;
  final String name;
  final int classLevel;
  final int avatar;
  final String parentPhone;
  final DateTime sentAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'classLevel': classLevel,
    'avatar': avatar,
    'parentPhone': parentPhone,
    'sentAt': sentAt.toIso8601String(),
  };
}

/// "98765 43210".
String formatPhone(String digits) => digits.length == 10
    ? '${digits.substring(0, 5)} ${digits.substring(5)}'
    : digits;

/// "+91 ••••• •6789": enough for a student to recognise, not to copy.
String maskPhone(String digits) =>
    digits.length == 10 ? '+91 ••••• •${digits.substring(6)}' : '+91 $digits';

// ---- Teacher -------------------------------------------------------------

class ClassStudent {
  const ClassStudent({
    required this.name,
    this.lastActive,
    this.mastery,
    this.awaitingParent = false,
  });

  factory ClassStudent.fromJson(Map<String, dynamic> j) => ClassStudent(
    name: j['name'] as String,
    lastActive: j['lastActive'] == null
        ? null
        : DateTime.parse(j['lastActive'] as String),
    mastery: (j['mastery'] as num?)?.toDouble(),
    awaitingParent: j['awaitingParent'] as bool? ?? false,
  );

  final String name;
  final DateTime? lastActive;

  /// Average chapter mastery, 0–1. Null until they have studied.
  final double? mastery;

  /// Joined with the code; not shown progress until a parent approves.
  final bool awaitingParent;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'lastActive': lastActive?.toIso8601String(),
    'mastery': mastery,
    'awaitingParent': awaitingParent,
  };
}

enum AssignmentKind { deck, quiz }

class Assignment {
  Assignment({
    required this.id,
    required this.kind,
    required this.subjectId,
    required this.chapterId,
    required this.due,
    required this.createdAt,
    this.cardIds,
  });

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
    id: j['id'] as String,
    kind: AssignmentKind.values.byName(j['kind'] as String),
    subjectId: j['subjectId'] as String,
    chapterId: j['chapterId'] as String,
    due: DateTime.parse(j['due'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    cardIds: (j['cardIds'] as List?)?.cast<String>(),
  );

  final String id;
  final AssignmentKind kind;
  final String subjectId;
  final String chapterId;

  /// Due by 11:59 pm on this day.
  final DateTime due;
  final DateTime createdAt;

  /// Just these cards from the chapter (a revision deck made from a quiz's
  /// weakest questions). Null means the whole chapter.
  final List<String>? cardIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'subjectId': subjectId,
    'chapterId': chapterId,
    'due': due.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    if (cardIds != null) 'cardIds': cardIds,
  };
}

class TeacherClass {
  TeacherClass({
    required this.id,
    required this.school,
    required this.subjectId,
    required this.classLevel,
    required this.section,
    required this.joinCode,
    required this.size,
    required this.students,
    required this.assignments,
  });

  factory TeacherClass.fromJson(Map<String, dynamic> j) => TeacherClass(
    id: j['id'] as String,
    school: j['school'] as String,
    subjectId: j['subjectId'] as String,
    classLevel: j['classLevel'] as int,
    section: j['section'] as String,
    joinCode: j['joinCode'] as String,
    size: j['size'] as int,
    students: [
      for (final s in j['students'] as List)
        ClassStudent.fromJson((s as Map).cast<String, dynamic>()),
    ],
    assignments: [
      for (final a in j['assignments'] as List)
        Assignment.fromJson((a as Map).cast<String, dynamic>()),
    ],
  );

  final String id;
  final String school;
  final String subjectId;
  final int classLevel;
  final String section;

  /// Six letters and digits that students type to join.
  final String joinCode;

  /// Students on the register, joined or not.
  final int size;
  final List<ClassStudent> students;

  /// Newest first.
  final List<Assignment> assignments;

  /// Students whose parent has approved.
  List<ClassStudent> get approved =>
      students.where((s) => !s.awaitingParent).toList();

  String get label => 'Class $classLevel · Section $section';
  String get shortLabel => '$classLevel$section';

  Map<String, dynamic> toJson() => {
    'id': id,
    'school': school,
    'subjectId': subjectId,
    'classLevel': classLevel,
    'section': section,
    'joinCode': joinCode,
    'size': size,
    'students': [for (final s in students) s.toJson()],
    'assignments': [for (final a in assignments) a.toJson()],
  };
}

/// How a class did on one assignment.
class AssignmentResults {
  const AssignmentResults({
    required this.done,
    required this.notYet,
    required this.questions,
  });

  final List<StudentResult> done;
  final List<ClassStudent> notYet;

  /// Per question, for quizzes only; weakest first.
  final List<QuestionStat> questions;

  double get averageScore => done.isEmpty
      ? 0
      : done.map((r) => r.score).reduce((a, b) => a + b) / done.length;
}

class StudentResult {
  const StudentResult({
    required this.student,
    required this.finishedAt,
    required this.score,
    required this.total,
  });

  final ClassStudent student;
  final DateTime finishedAt;
  final int score;
  final int total;
}

class QuestionStat {
  const QuestionStat({
    required this.cardId,
    required this.number,
    required this.text,
    required this.rightShare,
    this.commonWrong,
  });

  final String cardId;

  /// 1-based position in the quiz.
  final int number;
  final String text;
  final double rightShare;

  /// The wrong answer picked most, as "B · text".
  final String? commonWrong;
}
