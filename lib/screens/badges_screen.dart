import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../logic/levels.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

enum _Filter { all, earned, locked }

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  var _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.current!;
    final junior = Tier.of(context).isJunior;
    final facts = state.badgeFacts();
    final badges = state.badgeList;
    final earned = badges.where((b) => p.badges.containsKey(b.id)).toList();
    final shown = switch (_filter) {
      _Filter.all => badges,
      _Filter.earned => earned,
      _Filter.locked => [
        for (final b in badges)
          if (!p.badges.containsKey(b.id)) b,
      ],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                junior ? 'My badges' : 'Badges',
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: junior ? 30 : 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (junior)
              ReadAloudButton(
                'You are level ${state.level.number}, ${state.level.name}. '
                'You have won ${earned.length} of ${badges.length} badges.',
              )
            else
              const SwitchStudentButton(),
          ],
        ),
        const SizedBox(height: 16),
        _LevelCard(level: state.level, xp: p.xp, junior: junior),
        const SizedBox(height: 20),
        if (junior)
          Text(
            'Badges · ${earned.length} of ${badges.length} won',
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          SegmentedButton<_Filter>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _Filter.all,
                label: Text('All ${badges.length}'),
              ),
              ButtonSegment(
                value: _Filter.earned,
                label: Text('Earned ${earned.length}'),
              ),
              ButtonSegment(
                value: _Filter.locked,
                label: Text('Locked ${badges.length - earned.length}'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: junior ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: junior ? 0.72 : 0.95,
          children: [
            for (final b in junior ? badges : shown)
              BadgeTile(
                badge: b,
                earnedOn: p.badges[b.id],
                progress: b.progress(facts),
                junior: junior,
                now: state.now(),
              ),
          ],
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.xp,
    required this.junior,
  });

  final Level level;
  final int xp;
  final bool junior;

  @override
  Widget build(BuildContext context) {
    final inLevel = xp - level.start;
    final toGo = level.next - xp;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(junior ? 28 : 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${level.number}',
                  style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      junior ? 'LEVEL ${level.number}' : 'LVL ${level.number}',
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTint,
                      ),
                    ),
                    Text(
                      level.name,
                      style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: junior ? 26 : 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      junior
                          ? '$toGo XP to Level ${level.number + 1}'
                          : '$toGo XP to Level ${level.number + 1}, ${level.nextName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: inLevel / level.span,
              minHeight: 12,
              color: AppColors.star,
              backgroundColor: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  junior
                      ? '$inLevel / ${level.span} XP'
                      : '${formatCount(xp)} XP',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!junior)
                Text(
                  '${formatCount(level.next)} XP',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryTint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            junior
                ? 'Every right answer gives you XP'
                : '+${Xp.perRightAnswer} per right answer · '
                      '+${Xp.threeStarBonus} for 3 stars · '
                      '+${Xp.dailyGoalBonus} daily goal',
            style: const TextStyle(fontSize: 13, color: AppColors.primaryTint),
          ),
        ],
      ),
    );
  }
}

class BadgeTile extends StatelessWidget {
  const BadgeTile({
    super.key,
    required this.badge,
    required this.earnedOn,
    required this.progress,
    required this.junior,
    required this.now,
  });

  final BadgeDef badge;

  /// yyyy-mm-dd, '' if the date is unknown, null if not earned.
  final String? earnedOn;
  final (int, int) progress;
  final bool junior;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final unlocked = earnedOn != null;
    final (cur, target) = progress;
    final date = unlocked && earnedOn!.isNotEmpty
        ? shortDate(now, DateTime.parse(earnedOn!))
        : null;
    final caption = unlocked
        ? (date ?? 'Earned')
        : target > 1
        ? '$cur / $target'
        : badge.description;
    return Semantics(
      label:
          '${badge.title}. ${badge.description}. '
          '${unlocked ? 'Earned' : 'Locked, $cur of $target'}',
      excludeSemantics: true,
      child: SoftCard(
        padding: junior ? 8 : 12,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BadgeMedal(unlocked: unlocked, size: junior ? 56 : 60),
            const SizedBox(height: 6),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: junior ? 14 : 15,
                fontWeight: FontWeight.w800,
                color: unlocked ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
            if (!junior) ...[
              Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              if (!unlocked && target > 1) ...[
                const SizedBox(height: 6),
                ProgressBar(cur / target, height: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }
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

/// "BADGE UNLOCKED" card on results screens.
class NewBadgeCard extends StatelessWidget {
  const NewBadgeCard({super.key, required this.badge});
  final BadgeDef badge;

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
                badge.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                badge.description,
                style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
