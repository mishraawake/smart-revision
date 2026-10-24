import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/account_service.dart';
import '../data/speaker.dart';
import '../models/account.dart';

/// Phone-wide settings from the Settings screen.
class AppSettings {
  AppSettings({this.vibrate = false, this.speed = SpeechSpeed.normal});

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    vibrate: j['vibrate'] as bool? ?? false,
    speed: SpeechSpeed.values.byName(j['speed'] as String? ?? 'normal'),
  );

  bool vibrate;
  SpeechSpeed speed;

  Map<String, dynamic> toJson() => {'vibrate': vibrate, 'speed': speed.name};
}

/// Who is signed in, a student's pending approval, a teacher's classes and
/// settings. Study progress stays in AppState.
class AccountState extends ChangeNotifier {
  AccountState({required this.service, this.speaker});

  static const _accountKey = 'account.v1';
  static const _requestKey = 'approvalRequest.v1';
  static const _settingsKey = 'settings.v1';

  final AccountService service;

  /// Gets the read-aloud speed whenever it changes.
  final Speaker? speaker;

  bool loaded = false;
  Account? account;
  ApprovalRequest? pending;
  AppSettings settings = AppSettings();

  /// A parent is looking at the grown-up screens rather than handing the
  /// phone to a child.
  bool adultMode = false;

  List<TeacherClass> classes = [];
  int classIndex = 0;

  TeacherClass? get currentClass =>
      classes.isEmpty ? null : classes[classIndex.clamp(0, classes.length - 1)];

  /// Loads what was saved. [hasProfiles] marks phones set up before sign-in
  /// existed: they carry on as a parent's phone without signing in.
  Future<void> load({required bool hasProfiles}) async {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString(_accountKey);
    final r = prefs.getString(_requestKey);
    final s = prefs.getString(_settingsKey);
    account = a == null
        ? null
        : Account.fromJson(jsonDecode(a) as Map<String, dynamic>);
    pending = r == null
        ? null
        : ApprovalRequest.fromJson(jsonDecode(r) as Map<String, dynamic>);
    settings = s == null
        ? AppSettings()
        : AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
    speaker?.speed = settings.speed;
    if (account == null && pending == null && hasProfiles) {
      account = Account(role: Role.parent);
      await _saveAccount();
    }
    if (account?.role == Role.teacher) await loadClasses();
    loaded = true;
    notifyListeners();
  }

  Future<void> _saveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    if (account == null) {
      await prefs.remove(_accountKey);
    } else {
      await prefs.setString(_accountKey, jsonEncode(account!.toJson()));
    }
  }

  /// Called once the OTP checks out. Throws [AccountException] if the number
  /// is already set up for another role.
  Future<void> signIn(Role role, String phone) async {
    await service.register(role, phone);
    account = Account(
      role: role,
      phone: phone,
      consentAt: role == Role.parent ? DateTime.now() : null,
    );
    adultMode = role == Role.parent;
    await _saveAccount();
    if (role == Role.teacher) await loadClasses();
    notifyListeners();
  }

  Future<void> signOut() async {
    await service.signOut();
    account = null;
    pending = null;
    adultMode = false;
    classes = [];
    classIndex = 0;
    requests = [];
    assignments = [];
    _assignmentsChild = null;
    await _saveAccount();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestKey);
    notifyListeners();
  }

  void setAdultMode(bool on) {
    adultMode = on;
    notifyListeners();
  }

  // ---- Student sign-up ----------------------------------------------------

  Future<void> requestApproval({
    required String name,
    required int classLevel,
    required int avatar,
    required String parentPhone,
  }) async {
    pending = await service.requestApproval(
      name: name,
      classLevel: classLevel,
      avatar: avatar,
      parentPhone: parentPhone,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_requestKey, jsonEncode(pending!.toJson()));
    notifyListeners();
  }

  /// Back to the sign-up form, to fix a wrong number.
  Future<void> cancelRequest() async {
    pending = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestKey);
    notifyListeners();
  }

  /// Checks once; returns the request when it has just been approved so the
  /// caller can create the student's profile.
  Future<(ApprovalRequest, String)?> checkApproval() async {
    final r = pending;
    if (r == null) return null;
    final childId = await service.approvedChildId(r);
    if (childId == null) return null;
    await service.register(Role.student, '');
    pending = null;
    account = Account(role: Role.student);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestKey);
    await _saveAccount();
    notifyListeners();
    return (r, childId);
  }

  // ---- Parent -------------------------------------------------------------

  /// Students waiting for this parent to say yes.
  List<ApprovalRequest> requests = [];

  bool get _syncs => !service.isDemo && account?.role == Role.parent;

  Future<void> loadRequests() async {
    if (!_syncs) return;
    requests = await service.requestsForMe();
    notifyListeners();
  }

  /// Returns the new child's id for the caller to add a profile.
  Future<String> approve(ApprovalRequest r) async {
    final id = await service.approve(r);
    requests = [...requests]..remove(r);
    notifyListeners();
    return id;
  }

  Future<void> decline(ApprovalRequest r) async {
    await service.decline(r);
    requests = [...requests]..remove(r);
    notifyListeners();
  }

  Future<List<ChildRecord>> loadChildren() async =>
      _syncs ? service.loadChildren() : const [];

  /// Keeps the server copy of a parent's child up to date. Fails quietly:
  /// the profile works on the phone either way and syncs next time.
  Future<void> saveChild(ChildRecord child) async {
    if (!_syncs) return;
    try {
      await service.saveChild(child);
    } on AccountException {
      // Offline; try again on the next change.
    }
  }

  // ---- Student ------------------------------------------------------------

  /// Open work from teachers for the profile being studied.
  List<StudentAssignment> assignments = [];
  String? _assignmentsChild;

  Future<void> loadAssignments(String childId) async {
    _assignmentsChild = childId;
    if (service.isDemo || account == null) return;
    try {
      final list = await service.assignmentsFor(childId);
      if (_assignmentsChild != childId) return; // Switched student meanwhile.
      assignments = list;
      notifyListeners();
    } on AccountException {
      // Offline: keep what we had.
    }
  }

  Future<JoinResult> joinClass(String code, ChildRecord child) async {
    final r = await service.joinClass(code.trim().toUpperCase(), child);
    if (r == JoinResult.joined) await loadAssignments(child.id);
    return r;
  }

  /// Hands in a finished quiz if a teacher set one on this chapter.
  Future<void> submitQuiz(
    String childId,
    String chapterId, {
    required int score,
    required int total,
    required List<Map<String, Object?>> answers,
  }) async {
    final open = assignments.where(
      (a) =>
          !a.done &&
          a.assignment.kind == AssignmentKind.quiz &&
          a.assignment.chapterId == chapterId,
    );
    if (open.isEmpty) return;
    try {
      await service.submit(
        open.first,
        childId,
        score: score,
        total: total,
        answers: answers,
      );
      await loadAssignments(childId);
    } on AccountException {
      // Offline: the score stays on the phone; the teacher won't see it.
    }
  }

  // ---- Teacher ------------------------------------------------------------

  Future<void> loadClasses() async {
    classes = await service.loadClasses();
    notifyListeners();
  }

  void selectClass(int i) {
    classIndex = i;
    notifyListeners();
  }

  Future<void> createClass({
    required String school,
    required int classLevel,
    required String section,
    required String subjectId,
  }) async {
    final c = await service.createClass(
      school: school,
      classLevel: classLevel,
      section: section,
      subjectId: subjectId,
    );
    classes = [...classes, c];
    classIndex = classes.length - 1;
    notifyListeners();
  }

  Future<void> addAssignment(Assignment a) async {
    await service.addAssignment(currentClass!, a);
    notifyListeners();
  }

  // ---- Settings -----------------------------------------------------------

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    change(settings);
    speaker?.speed = settings.speed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    notifyListeners();
  }
}

class AccountScope extends InheritedNotifier<AccountState> {
  const AccountScope({
    super.key,
    required AccountState state,
    required super.child,
  }) : super(notifier: state);

  static AccountState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()!.notifier!;

  static AccountState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;

  static AccountState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccountScope>()!.notifier!;
}
