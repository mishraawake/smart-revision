import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).current!;
    final junior = Tier.of(context).isJunior;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Badges',
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: junior ? 30 : 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (junior) ReadAloudButton('You have ${p.badges.length} badges.'),
          ],
        ),
        Text(
          '${p.badges.length} of ${BadgeDef.all.length} unlocked',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            for (final b in BadgeDef.all)
              BadgeTile(badge: b, unlocked: p.badges.contains(b.id)),
          ],
        ),
      ],
    );
  }
}

class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge, required this.unlocked});
  final BadgeDef badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BadgeMedal(unlocked: unlocked),
        const SizedBox(height: 8),
        Text(
          badge.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: unlocked ? AppColors.ink : AppColors.inkMuted,
          ),
        ),
        Text(
          badge.description,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      ],
    ),
  );
}

class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.unlocked, this.size = 64});
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: unlocked ? AppColors.starBg : AppColors.chip,
      border: Border.all(
        color: unlocked ? AppColors.star : AppColors.groundBorder,
        width: 3,
      ),
    ),
    child: Icon(
      unlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
      size: size * 0.5,
      color: unlocked ? AppColors.starStroke : AppColors.inkMuted,
    ),
  );
}
