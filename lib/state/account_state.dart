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

  /// Called once the OTP checks out.
  Future<void> signIn(Role role, String phone) async {
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
    account = null;
    pending = null;
    adultMode = false;
    classes = [];
    classIndex = 0;
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
  Future<ApprovalRequest?> checkApproval() async {
    final r = pending;
    if (r == null || !await service.isApproved(r)) return null;
    pending = null;
    account = Account(role: Role.student);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestKey);
    await _saveAccount();
    notifyListeners();
    return r;
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
