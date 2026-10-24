import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The student ticks what their class has done at school, so new cards come
/// from chapters they've been taught.
class MyChaptersScreen extends StatelessWidget {
  const MyChaptersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.current!;
    final junior = Tier.of(context).isJunior;
    final subjects = state.deck?.subjects ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Done at school')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            p.covered.isEmpty
                ? 'Tick the chapters your class has finished. New cards will '
                      'come only from those. Nothing ticked means every '
                      'chapter.'
                : 'New cards come only from ticked chapters. Untick them all '
                      'to get every chapter again.',
            style: TextStyle(
              fontSize: junior ? 17 : 15,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
          for (final s in subjects) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                SubjectBadge(s.id, size: 36),
                const SizedBox(width: 10),
                Text(
                  s.name,
                  style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: junior ? 22 : 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SoftCard(
              padding: 4,
              child: Column(
                children: [
                  for (final ch in s.chapters)
                    CheckboxListTile(
                      value: p.covered.contains(ch.id),
                      onChanged: (v) => state.setCovered(ch.id, done: v!),
                      title: Text(
                        'Ch ${ch.number} · ${ch.title}',
                        style: TextStyle(
                          fontSize: junior ? 18 : 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
