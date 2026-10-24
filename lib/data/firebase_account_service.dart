import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/deck.dart';
import 'account_service.dart';

/// The real backend: phone sign-in with Firebase Auth, everything shared in
/// Firestore. The data model and who may touch what are in
/// firebase/firestore.rules.
class FirebaseAccountService implements AccountService {
  FirebaseAccountService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw const AccountException('Please sign in again.');
    return u.uid;
  }

  @override
  bool get isDemo => false;

  @override
  String? get demoOtp => null;

  @override
  bool get canRemind => false;

  /// Turns Firebase errors into something a parent can act on.
  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseAuthException catch (e) {
      throw AccountException(_authMessage(e));
    } on FirebaseException catch (e) {
      throw AccountException(switch (e.code) {
        'unavailable' => 'No internet. Check your connection and try again.',
        'permission-denied' => "You don't have access to that.",
        _ => 'Something went wrong. Please try again.',
      });
    }
  }

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
    'invalid-phone-number' => "That number doesn't look right.",
    'too-many-requests' ||
    'quota-exceeded' => 'Too many tries. Please wait a while and try again.',
    'network-request-failed' =>
      'No internet. Check your connection and try again.',
    'session-expired' ||
    'code-expired' => 'That code has expired. Ask for a new one.',
    _ => e.message ?? 'Something went wrong. Please try again.',
  };

  // ---- Sign-in ------------------------------------------------------------

  @override
  Future<void> sendOtp(String phone, {bool call = false}) => _run(() async {
    final number = '+91$phone';
    if (kIsWeb) {
      _webConfirmation = await _auth.signInWithPhoneNumber(number);
      return;
    }
    final sent = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: number,
      forceResendingToken: _resendToken,
      // Some Android phones read the SMS themselves and sign in directly.
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
        } on FirebaseAuthException {
          // The typed code still works.
        }
        if (!sent.isCompleted) sent.complete();
      },
      verificationFailed: (e) {
        if (!sent.isCompleted) {
          sent.completeError(AccountException(_authMessage(e)));
        }
      },
      codeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        if (!sent.isCompleted) sent.complete();
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
    return sent.future;
  });

  @override
  Future<bool> verifyOtp(String phone, String code) => _run(() async {
    if (_auth.currentUser?.phoneNumber == '+91$phone') return true;
    try {
      if (kIsWeb) {
        final c = _webConfirmation;
        if (c == null) return false;
        await c.confirm(code);
      } else {
        final id = _verificationId;
        if (id == null) return false;
        await _auth.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: id, smsCode: code),
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') return false;
      rethrow;
    }
  });

  @override
  Future<void> register(Role role, String phone) => _run(() async {
    final ref = _db.doc('users/$_uid');
    final snap = await ref.get();
    if (snap.exists) {
      final had = snap.data()!['role'] as String;
      if (had != role.name) {
        throw AccountException(
          'This number is already set up for a $had. Log in as a $had '
          'instead.',
        );
      }
      return;
    }
    await ref.set({
      'role': role.name,
      if (role != Role.student) 'phone': '+91$phone',
      if (role == Role.parent) 'consentAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> signOut() => _auth.signOut();

  // ---- Student sign-up ----------------------------------------------------

  @override
  Future<ApprovalRequest> requestApproval({
    required String name,
    required int classLevel,
    required int avatar,
    required String parentPhone,
  }) => _run(() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    final ref = _db.collection('approvalRequests').doc();
    await ref.set({
      'studentUid': _uid,
      'name': name,
      'classLevel': classLevel,
      'avatar': avatar,
      'parentPhone': parentPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ApprovalRequest(
      id: ref.id,
      name: name,
      classLevel: classLevel,
      avatar: avatar,
      parentPhone: parentPhone,
      sentAt: DateTime.now(),
    );
  });

  @override
  Future<String?> approvedChildId(ApprovalRequest request) => _run(() async {
    final snap = await _db.doc('approvalRequests/${request.id}').get();
    if (snap.data()?['status'] != 'approved') return null;
    final mine = await _db
        .collection('children')
        .where('studentUid', isEqualTo: _uid)
        .limit(1)
        .get();
    return mine.docs.firstOrNull?.id;
  });

  // ---- Parent -------------------------------------------------------------

  @override
  Future<List<ChildRecord>> loadChildren() => _run(() async {
    final q = await _db
        .collection('children')
        .where('parentUid', isEqualTo: _uid)
        .get();
    return [
      for (final d in q.docs)
        ChildRecord(
          id: d.id,
          name: d['name'] as String,
          classLevel: d['classLevel'] as int,
          avatar: d['avatar'] as int,
        ),
    ];
  });

  @override
  Future<void> saveChild(ChildRecord child) => _run(() async {
    final ref = _db.doc('children/${child.id}');
    final fields = {
      'name': child.name,
      'classLevel': child.classLevel,
      'avatar': child.avatar,
    };
    if ((await ref.get()).exists) {
      await ref.update(fields);
    } else {
      await ref.set({
        ...fields,
        'parentUid': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  });

  String get _myDigits {
    final p = _auth.currentUser?.phoneNumber ?? '';
    return p.startsWith('+91') ? p.substring(3) : p;
  }

  @override
  Future<List<ApprovalRequest>> requestsForMe() => _run(() async {
    final q = await _db
        .collection('approvalRequests')
        .where('parentPhone', isEqualTo: _myDigits)
        .where('status', isEqualTo: 'pending')
        .get();
    final now = DateTime.now();
    return [
      for (final d in q.docs)
        if ((d['createdAt'] as Timestamp?)?.toDate() case final sent?)
          if (now.difference(sent) < ApprovalRequest.validFor)
            ApprovalRequest(
              id: d.id,
              name: d['name'] as String,
              classLevel: d['classLevel'] as int,
              avatar: d['avatar'] as int,
              parentPhone: d['parentPhone'] as String,
              sentAt: sent,
            ),
    ];
  });

  @override
  Future<String> approve(ApprovalRequest request) => _run(() async {
    final reqRef = _db.doc('approvalRequests/${request.id}');
    final studentUid = (await reqRef.get()).data()?['studentUid'] as String?;
    if (studentUid == null) {
      throw const AccountException('That request has been withdrawn.');
    }
    final childRef = _db.collection('children').doc();
    await (_db.batch()
          ..update(reqRef, {
            'status': 'approved',
            'decidedAt': FieldValue.serverTimestamp(),
          })
          ..set(childRef, {
            'parentUid': _uid,
            'studentUid': studentUid,
            'fromRequest': request.id,
            'name': request.name,
            'classLevel': request.classLevel,
            'avatar': request.avatar,
            'createdAt': FieldValue.serverTimestamp(),
          }))
        .commit();
    return childRef.id;
  });

  @override
  Future<void> decline(ApprovalRequest request) => _run(
    () => _db.doc('approvalRequests/${request.id}').update({
      'status': 'declined',
      'decidedAt': FieldValue.serverTimestamp(),
    }),
  );

  // ---- Student ------------------------------------------------------------

  @override
  Future<JoinResult> joinClass(String code, ChildRecord child) =>
      _run(() async {
        final codeSnap = await _db.doc('joinCodes/${code.toUpperCase()}').get();
        if (!codeSnap.exists) return JoinResult.badCode;
        if (codeSnap['classLevel'] != child.classLevel) {
          return JoinResult.wrongClass;
        }
        final classId = codeSnap['classId'] as String;
        final memberRef = _db.doc('classes/$classId/members/${child.id}');
        try {
          if ((await memberRef.get()).exists) return JoinResult.alreadyIn;
        } on FirebaseException {
          // Not readable means not a member yet.
        }

        var childSnap = await _db.doc('children/${child.id}').get();
        if (!childSnap.exists) {
          // A profile made before sign-in existed: put it on the server.
          await saveChild(child);
          childSnap = await _db.doc('children/${child.id}').get();
        }
        final parentUid = childSnap['parentUid'] as String;
        final studentUid = childSnap.data()?['studentUid'] as String?;
        await (_db.batch()
              ..update(_db.doc('classes/$classId'), {
                'memberUids': FieldValue.arrayUnion([_uid]),
              })
              ..set(memberRef, {
                'uids': [parentUid, ?studentUid],
                'name': childSnap['name'],
                'parentApproved': parentUid == _uid,
                'joinedAt': FieldValue.serverTimestamp(),
              }))
            .commit();
        return JoinResult.joined;
      });

  @override
  Future<List<StudentAssignment>> assignmentsFor(String childId) =>
      _run(() async {
        final classes = await _db
            .collection('classes')
            .where('memberUids', arrayContains: _uid)
            .get();
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        final out = <StudentAssignment>[];
        for (final c in classes.docs) {
          try {
            if (!(await c.reference.collection('members').doc(childId).get())
                .exists) {
              continue;
            }
          } on FirebaseException {
            continue; // Another child of this parent is the member.
          }
          final label = 'Class ${c['classLevel']} · Section ${c['section']}';
          final work = await c.reference.collection('assignments').get();
          for (final d in work.docs) {
            final a = _assignment(d);
            if (a.due.isBefore(start)) continue;
            final done =
                (await d.reference.collection('submissions').doc(childId).get())
                    .exists;
            out.add(
              StudentAssignment(
                classId: c.id,
                classLabel: label,
                assignment: a,
                done: done,
              ),
            );
          }
        }
        out.sort((a, b) => a.assignment.due.compareTo(b.assignment.due));
        return out;
      });

  @override
  Future<void> submit(
    StudentAssignment a,
    String childId, {
    required int score,
    required int total,
    required List<Map<String, Object?>> answers,
  }) => _run(
    () => _db
        .doc(
          'classes/${a.classId}/assignments/${a.assignment.id}/'
          'submissions/$childId',
        )
        .set({
          'score': score,
          'total': total,
          'answers': answers.take(50).toList(),
          'finishedAt': FieldValue.serverTimestamp(),
        }),
  );

  // ---- Teacher ------------------------------------------------------------

  static Assignment _assignment(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data()!;
    return Assignment(
      id: d.id,
      kind: AssignmentKind.values.byName(j['kind'] as String),
      subjectId: j['subjectId'] as String,
      chapterId: j['chapterId'] as String,
      due: (j['due'] as Timestamp).toDate(),
      createdAt: (j['createdAt'] as Timestamp).toDate(),
      cardIds: (j['cardIds'] as List?)?.cast<String>(),
    );
  }

  Future<TeacherClass> _teacherClass(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) async {
    final j = d.data()!;
    final members = await d.reference.collection('members').get();
    final work = await d.reference
        .collection('assignments')
        .orderBy('createdAt', descending: true)
        .get();
    return TeacherClass(
      id: d.id,
      school: j['school'] as String,
      subjectId: j['subjectId'] as String,
      classLevel: j['classLevel'] as int,
      section: j['section'] as String,
      joinCode: j['joinCode'] as String,
      size: j['size'] as int? ?? 0,
      students: [
        for (final m in members.docs)
          ClassStudent(
            id: m.id,
            name: m['name'] as String,
            lastActive: (m.data()['lastActive'] as Timestamp?)?.toDate(),
            mastery: (m.data()['mastery'] as num?)?.toDouble(),
            awaitingParent: m['parentApproved'] != true,
          ),
      ],
      assignments: [for (final a in work.docs) _assignment(a)],
    );
  }

  @override
  Future<List<TeacherClass>> loadClasses() => _run(() async {
    final q = await _db
        .collection('classes')
        .where('teacherUid', isEqualTo: _uid)
        .get();
    final classes = [for (final d in q.docs) await _teacherClass(d)];
    classes.sort((a, b) => a.label.compareTo(b.label));
    return classes;
  });

  @override
  Future<TeacherClass> createClass({
    required String school,
    required int classLevel,
    required String section,
    required String subjectId,
  }) => _run(() async {
    final rnd = Random.secure();
    // No 0/O or 1/I so the code reads aloud cleanly.
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    do {
      code = [for (var i = 0; i < 6; i++) letters[rnd.nextInt(letters.length)]]
          .join();
    } while ((await _db.doc('joinCodes/$code').get()).exists);

    final ref = _db.collection('classes').doc();
    await (_db.batch()
          ..set(ref, {
            'teacherUid': _uid,
            'school': school,
            'subjectId': subjectId,
            'classLevel': classLevel,
            'section': section,
            'joinCode': code,
            'size': 0,
            'memberUids': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(_db.doc('joinCodes/$code'), {
            'classId': ref.id,
            'teacherUid': _uid,
            'classLevel': classLevel,
          }))
        .commit();
    return TeacherClass(
      id: ref.id,
      school: school,
      subjectId: subjectId,
      classLevel: classLevel,
      section: section,
      joinCode: code,
      size: 0,
      students: [],
      assignments: [],
    );
  });

  @override
  Future<void> addAssignment(TeacherClass c, Assignment a) => _run(() async {
    await _db.doc('classes/${c.id}/assignments/${a.id}').set({
      'kind': a.kind.name,
      'subjectId': a.subjectId,
      'chapterId': a.chapterId,
      'cardIds': ?a.cardIds,
      'due': Timestamp.fromDate(a.due),
      'createdAt': Timestamp.fromDate(a.createdAt),
    });
    c.assignments.insert(0, a);
  });

  @override
  Future<AssignmentResults> results(
    TeacherClass c,
    Assignment a,
    Chapter chapter,
  ) => _run(() async {
    final subs = await _db
        .collection('classes/${c.id}/assignments/${a.id}/submissions')
        .get();
    final byId = {for (final s in c.students) s.id: s};
    final done = <StudentResult>[];
    final asked = <String, int>{};
    final right = <String, int>{};
    final wrongPicks = <String, Map<String, int>>{};
    for (final d in subs.docs) {
      final student = byId[d.id];
      if (student == null) continue; // Left the class since.
      done.add(
        StudentResult(
          student: student,
          finishedAt: (d['finishedAt'] as Timestamp).toDate(),
          score: d['score'] as int,
          total: d['total'] as int,
        ),
      );
      for (final raw in (d['answers'] as List).cast<Map>()) {
        final id = raw['cardId'] as String?;
        if (id == null) continue;
        asked[id] = (asked[id] ?? 0) + 1;
        if (raw['right'] == true) {
          right[id] = (right[id] ?? 0) + 1;
        } else if (raw['given'] case final String given when given.isNotEmpty) {
          final picks = wrongPicks.putIfAbsent(id, () => {});
          picks[given] = (picks[given] ?? 0) + 1;
        }
      }
    }
    done.sort((x, y) => y.score.compareTo(x.score));
    final submitted = {for (final r in done) r.student.id};

    final order = [for (final card in chapter.cards) card.id];
    final questions = a.kind == AssignmentKind.deck
        ? <QuestionStat>[]
        : [
            for (final id in asked.keys)
              QuestionStat(
                cardId: id,
                number: order.indexOf(id) + 1,
                text:
                    chapter.cards.where((x) => x.id == id).firstOrNull?.front ??
                    id,
                rightShare: (right[id] ?? 0) / asked[id]!,
                commonWrong: wrongPicks[id]?.entries
                    .reduce((x, y) => x.value >= y.value ? x : y)
                    .key,
              ),
          ];
    questions.sort((x, y) => x.rightShare.compareTo(y.rightShare));
    return AssignmentResults(
      done: done,
      notYet: [
        for (final s in c.approved)
          if (!submitted.contains(s.id)) s,
      ],
      questions: questions,
    );
  });

  @override
  Future<void> remind(TeacherClass c, Assignment a) async {}
}
