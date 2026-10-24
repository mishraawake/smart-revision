import 'dart:math';

import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../screens/add_exam_sheet.dart';
import '../screens/review_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// On Today, under the teacher's work: the next test and how ready the
/// student is, and their mistakes to fix.
class StudyExtras extends StatelessWidget {
  const StudyExtras({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.deck == null) return const SizedBox.shrink();
    final exam = state.upcomingExams.firstOrNull;
    final mistakes = state.mistakes();
    final junior = Tier.of(context).isJunior;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exam != null)
          _ExamCard(exam: exam)
        else if (!junior)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () => showAddExamSheet(context),
                icon: const Icon(Icons.event_note_rounded, size: 20),
                label: const Text(
                  'Got a test coming? Add it',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
        if (mistakes.isNotEmpty) _MistakesCard(count: mistakes.length),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});
  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final junior = Tier.of(context).isJunior;
    final subject = state.subjectById(exam.subjectId);
    final days = state.daysUntil(exam);
    final ready = state.examReadiness(exam);
    final left = state.examCardsLeft(exam);
    final perDay = left == 0 ? 0 : (left / max(1, days)).ceil();
    final when = switch (days) {
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in $days days',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_rounded, color: AppColors.streak),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${subject?.name ?? 'Test'} test $when',
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: junior ? 20 : 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${(ready * 100).round()}% ready',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.knew,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBar(ready, color: AppColors.knew, height: junior ? 10 : 6),
            const SizedBox(height: 8),
            Text(
              left == 0
                  ? 'Every card learnt. Keep them fresh with a quick round.'
                  : 'About $perDay cards a day gets you there.',
              style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => startReview(context, state.examQueue(exam)),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Revise for it'),
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(junior ? 52 : 44),
                backgroundColor: AppColors.primaryTint,
                foregroundColor: AppColors.onPrimaryTint,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MistakesCard extends StatelessWidget {
  const _MistakesCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final junior = Tier.of(context).isJunior;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SoftCard(
        onTap: () => startReview(
          context,
          state.mistakes().take(state.sessionSize).toList(),
        ),
        child: Row(
          children: [
            Container(
              width: junior ? 52 : 44,
              height: junior ? 52 : 44,
              decoration: const BoxDecoration(
                color: AppColors.again,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                color: AppColors.againInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fix my mistakes',
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: junior ? 20 : 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$count ${count == 1 ? 'card' : 'cards'} you got wrong '
                    'last time',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
