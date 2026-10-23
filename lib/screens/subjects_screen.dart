import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'chapters_screen.dart';
import 'today_screen.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final deck = state.deck;
    final p = state.current!;
    if (deck == null) return NoContentView(classLevel: p.classLevel);
    final junior = Tier.of(context).isJunior;
    final due = state.dueBySubject();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Subjects',
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: junior ? 30 : 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (junior) const ReadAloudButton('Subjects. Pick one.'),
          ],
        ),
        Text(
          junior
              ? 'Class ${p.classLevel} · Pick one'
              : 'Class ${p.classLevel} · NCERT · ${(state.learntFraction(deck.allCards) * 100).round()}% mastered overall',
          style: TextStyle(
            fontSize: junior ? 18 : 15,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 16),
        for (final s in deck.subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              padding: junior ? 18 : 14,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChaptersScreen(subjectId: s.id),
                ),
              ),
              child: Row(
                children: [
                  SubjectBadge(s.id, size: junior ? 72 : 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: junior
                              ? const TextStyle(
                                  fontFamily: Fonts.display,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                )
                              : const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                        ),
                        if (!junior)
                          Text(
                            '${s.chapters.length} chapters',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          state.learntFraction(s.cards),
                          color: SubjectStyle.of(s.id).foreground,
                          height: junior ? 12 : 8,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(state.learntFraction(s.cards) * 100).round()}% ${junior ? 'learnt' : 'mastered'}',
                          style: TextStyle(
                            fontSize: junior ? 16 : 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!junior && (due[s.id] ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${due[s.id]} due',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
