import '../data/account_service.dart';
import '../logic/progress_merge.dart';
import '../models/account.dart';
import '../models/profile.dart';
import 'account_state.dart';
import 'app_state.dart';

/// Keeps each child's study progress on their account, so it follows them
/// to a new phone and adds up across two (a parent's and their own). Also
/// hands in finished deck homework and tells teachers how the child is doing.
///
/// Everything here is best effort: offline, it does nothing and the next
/// sync catches up.
class ProgressSync {
  ProgressSync({required this.app, required this.accounts});

  final AppState app;
  final AccountState accounts;

  AccountService get _service => accounts.service;
  final _busy = <String>{};

  /// Only signed-in accounts sync: a parent who logged in by phone, or a
  /// student on their own login.
  bool get _active {
    final a = accounts.account;
    if (_service.isDemo || a == null) return false;
    return switch (a.role) {
      Role.parent => a.phone != null,
      Role.student => true,
      Role.teacher => false,
    };
  }

  ChildRecord _record(Profile p) => ChildRecord(
    id: p.id,
    name: p.name,
    classLevel: p.classLevel,
    avatar: p.avatar,
  );

  /// Merges the server's copy of [p] into this phone's, saves the result
  /// here and there.
  Future<void> sync(Profile p) async {
    if (!_active || !_busy.add(p.id)) return;
    try {
      Map<String, dynamic>? remote;
      try {
        remote = await _service.loadProgress(p.id);
      } on AccountException {
        // A child made on this phone may not be on the account yet.
        if (accounts.account?.role != Role.parent) rethrow;
        await accounts.saveChild(_record(p));
        remote = await _service.loadProgress(p.id);
      }
      if (remote != null) {
        final theirs = Profile.fromJson({
          ...remote,
          'id': p.id,
          'name': p.name,
          'classLevel': p.classLevel,
          'avatar': p.avatar,
        });
        if (mergeProgress(p, theirs)) await app.persist();
      }
      await _service.saveProgress(p.id, p.toJson());
    } on AccountException {
      // Offline; next time.
    } finally {
      _busy.remove(p.id);
    }
  }

  /// After a session or quiz: save it, hand in deck homework that is now
  /// done, and update the child's row in each class.
  Future<void> afterSession() async {
    final p = app.current;
    if (p == null || !_active) return;
    await sync(p);
    await _deckHomework(p);
    await _report(p);
  }

  /// A deck is done once every card in it was reviewed after it was set.
  Future<void> _deckHomework(Profile p) async {
    final deck = app.deck;
    if (deck == null) return;
    for (final work in [...accounts.assignments]) {
      final a = work.assignment;
      if (work.done || a.kind != AssignmentKind.deck) continue;
      final chapter = deck.chapters.where((c) => c.id == a.chapterId);
      if (chapter.isEmpty) continue;
      final ids = a.cardIds ?? [for (final c in chapter.first.cards) c.id];
      if (ids.isEmpty) continue;
      final reviewed = ids.every((id) {
        final at = p.cards[id]?.at;
        return at != null && !at.isBefore(a.createdAt);
      });
      if (!reviewed) continue;
      await accounts.submitWork(
        work,
        p.id,
        score: ids.where((id) => p.cards[id]?.learnt ?? false).length,
        total: ids.length,
        answers: [
          for (final id in ids)
            {'cardId': id, 'right': p.cards[id]?.learnt ?? false},
        ],
      );
    }
  }

  /// Last active and mastery in the class's subject, where a parent agreed.
  Future<void> _report(Profile p) async {
    final deck = app.deck;
    if (deck == null) return;
    try {
      for (final m in await _service.membershipsFor(p.id)) {
        if (!m.approved) continue;
        final subject = deck.subjects.where((s) => s.id == m.subjectId);
        if (subject.isEmpty) continue;
        await _service.reportProgress(
          m.classId,
          p.id,
          mastery: app.subjectMastery(subject.first),
        );
      }
    } on AccountException {
      // Offline; reported after the next session.
    }
  }
}
