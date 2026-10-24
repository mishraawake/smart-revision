import 'package:flutter/material.dart';

import '../models/account.dart';
import '../screens/review_screen.dart';
import '../screens/join_class_dialog.dart';
import '../screens/quiz/quiz_intro_screen.dart';
import '../screens/teacher/teacher_shell.dart' show dueLabel;
import '../state/account_state.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// "From your teacher" on Today: open work, soonest first. A student on their
/// own login also gets a way to join a class here; on a parent's phone that
/// lives on the parent dashboard.
class TeacherWork extends StatelessWidget {
  const TeacherWork({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = AccountScope.maybeOf(context);
    final app = AppScope.of(context);
    final p = app.current;
    if (accounts == null || p == null || accounts.service.isDemo) {
      return const SizedBox.shrink();
    }
    final work = accounts.assignments;
    final ownLogin = accounts.account?.role == Role.student;
    if (work.isEmpty && !ownLogin) return const SizedBox.shrink();

    final junior = Tier.of(context).isJunior;
    final titleSize = junior ? 20.0 : 17.0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'From your teacher',
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (work.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Got a class code from your teacher? Join to see homework '
                'here.',
                style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
              ),
            ],
            for (final a in work) _Item(work: a, now: app.now()),
            if (ownLogin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showJoinClassDialog(context, p),
                  icon: const Icon(Icons.group_add_outlined, size: 20),
                  label: const Text(
                    'Join a class',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.work, required this.now});

  final StudentAssignment work;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final deck = AppScope.of(context).deck;
    final a = work.assignment;
    final chapter = deck?.chapters
        .where((c) => c.id == a.chapterId)
        .firstOrNull;
    if (chapter == null) return const SizedBox.shrink();
    final quiz = a.kind == AssignmentKind.quiz;
    final kind = quiz
        ? 'Quiz'
        : a.cardIds == null
        ? 'Deck'
        : 'Revision · ${a.cardIds!.length} cards';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: work.done ? AppColors.chip : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // A deck reviews exactly the cards set, due or not, so the
          // homework can be finished (a chapter review skips learnt cards).
          onTap: () => quiz
              ? openQuiz(context, chapter: chapter)
              : startReview(context, [
                  for (final c in chapter.cards)
                    if (a.cardIds?.contains(c.id) ?? true) c,
                ]),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  work.done
                      ? Icons.check_circle
                      : quiz
                      ? Icons.quiz_outlined
                      : Icons.style_outlined,
                  color: work.done ? AppColors.knew : AppColors.onPrimaryTint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        work.done
                            ? '$kind · Done'
                            : '$kind · ${dueLabel(now, a.due)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
