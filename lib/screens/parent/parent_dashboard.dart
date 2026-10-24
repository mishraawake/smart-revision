import 'package:flutter/material.dart';

import '../../logic/insights.dart';
import '../../models/deck.dart';
import '../../models/profile.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/format.dart';
import '../account/add_child_screen.dart';
import '../account/adult_widgets.dart';

/// One child at a time: this week's minutes, streak, chapters mastered,
/// weak chapters and recent quizzes.
class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key, required this.onSettings});
  final VoidCallback onSettings;

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  String? _childId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final kids = app.profiles;
    final now = app.now();
    final child =
        kids.where((p) => p.id == _childId).firstOrNull ?? kids.firstOrNull;
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week of ${weekStart.day}–${weekEnd.day} '
                    '${months[weekEnd.month - 1]}',
                    style: labelStyle,
                  ),
                  const Text(
                    'Your children',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: widget.onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in kids) ...[
                _ChildTab(
                  profile: p,
                  selected: p == child,
                  onTap: () => setState(() => _childId = p.id),
                ),
                const SizedBox(width: 8),
              ],
              IconButton.outlined(
                tooltip: 'Add a child',
                onPressed: () => pushAdult(context, const AddChildScreen()),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  side: const BorderSide(color: AdultColors.field, width: 1.5),
                  backgroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (child == null)
          AdultCard(
            child: Column(
              children: [
                const Text(
                  'Add your first child to see their progress here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Add a child',
                  onPressed: () => pushAdult(context, const AddChildScreen()),
                ),
              ],
            ),
          )
        else
          FutureBuilder<ClassDeck?>(
            key: ValueKey(child.id),
            future: app.decks.load(child.classLevel),
            builder: (context, snap) =>
                snap.connectionState != ConnectionState.done
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _ChildReport(
                    insights: ChildInsights(child, snap.data, now: now),
                    streak: app.streakOf(child),
                  ),
          ),
      ],
    );
  }
}

class _ChildTab extends StatelessWidget {
  const _ChildTab({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final Profile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AdultColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(name: profile.name, index: profile.avatar, size: 36),
              const SizedBox(width: 8),
              Text(
                '${profile.name} · ${profile.classLevel}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChildReport extends StatelessWidget {
  const _ChildReport({required this.insights, required this.streak});

  final ChildInsights insights;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final i = insights;
    final p = i.profile;
    final weak = i.needsPractice;
    final quizzes = i.recentQuizzes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'This week',
                trailing: Text('Goal ${i.minutesGoal} min/day'),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${i.weekTotal}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('minutes', style: labelStyle),
                ],
              ),
              const SizedBox(height: 12),
              _WeekBars(minutes: i.weekMinutes, goal: i.minutesGoal),
              const SizedBox(height: 10),
              Text(
                'Light bar = under the daily goal. Dashed line = '
                '${i.minutesGoal} min.',
                style: labelStyle.copyWith(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Streak',
                value: '$streak ${streak == 1 ? 'day' : 'days'}',
                sub: 'Best: ${i.bestStreak} days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Chapters mastered',
                value: '${i.mastered}',
                valueSuffix: ' of ${i.chapterCount}',
                sub: '80% or more',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AdultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(
                'Needs more practice',
                trailing: Text('by recall'),
              ),
              const SizedBox(height: 8),
              if (weak.isEmpty)
                Text(
                  p.cards.isEmpty
                      ? '${p.name} hasn\'t started any chapters yet.'
                      : 'Nothing below 80% recall. Nice work, ${p.name}!',
                  style: mutedStyle,
                ),
              for (final (ch, recall) in weak)
                _Row(
                  over:
                      '${i.subject(ch.subjectId)?.name ?? ''} · Ch ${ch.number}',
                  title: ch.title,
                  trailing: StatusChip(
                    '${(recall * 100).round()}% recall',
                    ChipTone.needsWork,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Recent quizzes'),
              const SizedBox(height: 8),
              if (quizzes.isEmpty)
                const Text('No quizzes yet.', style: mutedStyle),
              for (final q in quizzes)
                _Row(
                  over: q.chapterId == null
                      ? 'Mixed quiz'
                      : '${i.subject(q.subjectId)?.name ?? ''} · Ch '
                            '${i.chapter(q.chapterId)?.number ?? ''}',
                  title: shortDate(i.now, q.at),
                  trailing: Text(
                    '${q.score}/${q.total}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: q.accuracy < 0.6
                          ? AdultColors.needsWorkInk
                          : AppColors.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SecondaryButton(
          label: "Open ${p.name}'s app",
          icon: Icons.swap_horiz,
          onPressed: () async {
            final app = AppScope.read(context);
            AccountScope.read(context).setAdultMode(false);
            await app.select(p);
          },
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.minutes, required this.goal});

  final List<int?> minutes;
  final int goal;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    const height = 110.0;
    final top = [
      goal * 1.5,
      ...minutes.whereType<int>().map((m) => m.toDouble()),
    ].reduce((a, b) => a > b ? a : b);
    final label = [
      for (var d = 0; d < 7; d++)
        minutes[d] == null
            ? '${_names[d]} not yet'
            : '${_names[d]} ${minutes[d]}',
    ].join(', ');
    return Semantics(
      label: 'Minutes per day: $label',
      excludeSemantics: true,
      child: SizedBox(
        height: height + 22,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: height - goal / top * height,
              child: CustomPaint(
                size: const Size(double.infinity, 2),
                painter: _DashPainter(),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 22,
                          height: minutes[d] == null
                              ? 0
                              : (minutes[d]! / top * height).clamp(3, height),
                          decoration: BoxDecoration(
                            color: (minutes[d] ?? 0) >= goal
                                ? AppColors.primary
                                : AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_days[d], style: labelStyle),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.inkMuted
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.sub,
    this.valueSuffix,
  });

  final String label;
  final String value;
  final String? valueSuffix;
  final String sub;

  @override
  Widget build(BuildContext context) => AdultCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: value,
            children: [
              if (valueSuffix != null)
                TextSpan(
                  text: valueSuffix,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.inkMuted,
                  ),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(sub, style: labelStyle.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.over, required this.title, required this.trailing});

  final String over;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(over, style: labelStyle),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    ),
  );
}
