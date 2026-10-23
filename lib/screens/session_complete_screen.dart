import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'badges_screen.dart';
import 'review_screen.dart';

class SessionCompleteScreen extends StatelessWidget {
  const SessionCompleteScreen({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final junior = Tier.of(context).isJunior;
    return Scaffold(
      body: SafeArea(
        child: junior ? _Junior(summary: summary) : _Senior(summary: summary),
      ),
    );
  }
}

class _Junior extends StatelessWidget {
  const _Junior({required this.summary});
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name = state.current!.name;
    final s = summary;
    final streakUp = s.streakAfter > s.streakBefore;
    final badge = s.newBadges.firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const Center(child: Owl(size: 120)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Well done, $name!',
                        style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ReadAloudButton(
                      'Well done, $name! You knew ${s.knew} cards.',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!s.practice)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.starBg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StarIcon(size: 36),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '+${s.starsEarned} stars',
                              style: const TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.starInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Count(
                        knew: true,
                        n: s.knew,
                        label: 'knew',
                        big: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Count(
                        knew: false,
                        n: s.missed.length,
                        label: 'again',
                        big: true,
                      ),
                    ),
                  ],
                ),
                if (streakUp) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.streakBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const FlameIcon(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.streakAfter}-day streak!',
                                style: const TextStyle(
                                  fontFamily: Fonts.display,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.streakInk,
                                ),
                              ),
                              Text(
                                s.streakBefore == 0
                                    ? 'Come back tomorrow'
                                    : 'Up from ${s.streakBefore}. Come back tomorrow',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.streakInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (badge != null) ...[
                  const SizedBox(height: 16),
                  _NewBadge(title: badge.title, description: badge.description),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Done',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Senior extends StatelessWidget {
  const _Senior({required this.summary});
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final minutes = s.duration.inMinutes < 1 ? 1 : s.duration.inMinutes;
    final missed = s.missed.length;
    final parts = [
      '${s.total} cards',
      '$minutes min',
      if (s.goalReached) 'Daily goal reached',
      if (s.practice) 'Practice',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  size: 56,
                  color: AppColors.knew,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Session complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  parts.join(' · '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 16),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    // Tile padding plus label and value, grown with font size.
                    mainAxisExtent:
                        28 + MediaQuery.textScalerOf(context).scale(56),
                  ),
                  children: [
                    _Count(knew: true, n: s.knew, label: 'Knew it'),
                    _Count(knew: false, n: missed, label: "Didn't know"),
                    if (!s.practice) ...[
                      _Tile(
                        background: AppColors.starBg,
                        icon: const StarIcon(size: 16),
                        label: 'Stars earned',
                        labelColor: AppColors.starInk,
                        value: '+${s.starsEarned}',
                      ),
                      _Tile(
                        background: AppColors.streakBg,
                        icon: const FlameIcon(size: 16),
                        label: 'Streak',
                        labelColor: AppColors.streakInk,
                        value:
                            '${s.streakAfter} days'
                            '${s.streakAfter > s.streakBefore ? ' +1' : ''}',
                      ),
                    ],
                  ],
                ),
                for (final b in s.newBadges) ...[
                  const SizedBox(height: 10),
                  _NewBadge(title: b.title, description: b.description),
                ],
                if (!s.practice) ...[
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Coming up',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Tomorrow',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                            Text(
                              '${s.dueTomorrow} cards',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Back to Today',
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (missed > 0)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ReviewScreen(cards: s.missed, practice: true),
                ),
              ),
              child: Text('Practise the $missed I missed'),
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.knew,
    required this.n,
    required this.label,
    this.big = false,
  });
  final bool knew;
  final int n;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    if (big) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: knew ? AppColors.knew : AppColors.again,
          borderRadius: BorderRadius.circular(24),
          border: knew
              ? null
              : Border.all(color: AppColors.againBorder, width: 2),
        ),
        child: Column(
          children: [
            Icon(
              knew ? Icons.check_rounded : Icons.replay_rounded,
              size: 32,
              color: knew ? Colors.white : AppColors.againInk,
            ),
            Text(
              '$n $label',
              style: TextStyle(
                fontFamily: Fonts.display,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: knew ? Colors.white : AppColors.againInk,
              ),
            ),
          ],
        ),
      );
    }
    return _Tile(
      background: Colors.white,
      icon: Icon(
        knew ? Icons.check_rounded : Icons.replay_rounded,
        size: 16,
        color: knew ? AppColors.knew : AppColors.againBorder,
      ),
      label: label,
      labelColor: knew ? AppColors.knewInk : AppColors.againInk,
      value: '$n',
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.background,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.value,
  });

  final Color background;
  final Widget icon;
  final String label;
  final Color labelColor;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            icon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.star, width: 2),
    ),
    child: Row(
      children: [
        const BadgeMedal(unlocked: true, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BADGE UNLOCKED',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.starInk,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
