import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/speaker.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Read-aloud button. Sits to the right of the text it reads.
class ReadAloudButton extends StatelessWidget {
  const ReadAloudButton(
    this.text, {
    super.key,
    this.size = 56,
    this.filled = false,
  });

  final String text;
  final double size;

  /// Filled indigo, for the answer on the back of a Junior card.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final speaker = SpeakerScope.of(context);
    return Semantics(
      button: true,
      label: 'Read aloud: $text',
      excludeSemantics: true,
      child: Material(
        color: filled ? AppColors.primary : AppColors.primaryTint,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => speaker.say(text),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.volume_up_rounded,
              size: size / 2,
              color: filled ? Colors.white : AppColors.onPrimaryTint,
            ),
          ),
        ),
      ),
    );
  }
}

class SpeakerScope extends InheritedWidget {
  const SpeakerScope({super.key, required this.speaker, required super.child});

  final Speaker speaker;

  static Speaker of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SpeakerScope>()!.speaker;

  @override
  bool updateShouldNotify(SpeakerScope oldWidget) =>
      speaker != oldWidget.speaker;
}

/// The one indigo action on a screen, with the design's pressed-down shadow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tier = Tier.of(context);
    return Container(
      height: tier.primaryButtonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tier.radius),
        boxShadow: tier.isJunior
            ? const [
                BoxShadow(color: AppColors.primaryDark, offset: Offset(0, 6)),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tier.radius),
          ),
          textStyle: tier.isJunior
              ? const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                )
              : const TextStyle(
                  fontFamily: Fonts.body,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: tier.isJunior ? 30 : 22),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class StarIcon extends StatelessWidget {
  const StarIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.star_rounded, size: size, color: AppColors.star);
}

class FlameIcon extends StatelessWidget {
  const FlameIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.local_fire_department_rounded,
    size: size,
    color: AppColors.streak,
  );
}

/// Small rounded pill: "4-day streak", "120 stars".
class StatPill extends StatelessWidget {
  const StatPill.streak(int days, {super.key})
    : label = '$days-day streak',
      background = AppColors.streakBg,
      foreground = AppColors.streakInk,
      icon = const FlameIcon();

  StatPill.stars(int stars, {super.key})
    : label = '${formatCount(stars)} stars',
      background = AppColors.starBg,
      foreground = AppColors.starInk,
      icon = const StarIcon();

  final String label;
  final Color background;
  final Color foreground;
  final Widget icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

String formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// White rounded card with the warm drop shadow used throughout Junior.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.onTap,
  });

  final Widget child;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tier = Tier.of(context);
    final radius = BorderRadius.circular(tier.isJunior ? 24 : 16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tier.isJunior
            ? const [
                BoxShadow(color: AppColors.cardShadow, offset: Offset(0, 4)),
              ]
            : null,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      ),
    );
  }
}

/// Coloured square with the subject's glyph.
class SubjectBadge extends StatelessWidget {
  const SubjectBadge(this.subjectId, {super.key, this.size = 56});

  final String subjectId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subjectId);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        style.glyph,
        style: TextStyle(
          fontFamily: Fonts.display,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          color: style.foreground,
        ),
      ),
    );
  }
}

/// Thin rounded progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar(
    this.value, {
    super.key,
    this.color = AppColors.primary,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value,
      minHeight: height,
      color: color,
      backgroundColor: AppColors.chip,
    ),
  );
}

/// Daily goal ring.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.done,
    required this.goal,
    required this.size,
    required this.label,
    this.stroke = 12,
  });

  final int done;
  final int goal;
  final double size;
  final double stroke;
  final Widget label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Daily goal: $done of $goal cards done',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          goal == 0 ? 0 : (done / goal).clamp(0, 1),
          stroke,
        ),
        child: Center(child: label),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.stroke);
  final double fraction;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = AppColors.chip);
    if (fraction > 0) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        paint..color = AppColors.star,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// "Ullu" the owl. Placeholder art until the final mascot arrives.
class Owl extends StatelessWidget {
  const Owl({super.key, this.size = 88, this.sleeping = false});

  final double size;
  final bool sleeping;

  @override
  Widget build(BuildContext context) => Semantics(
    label: sleeping ? 'Ullu the owl, resting' : 'Ullu the owl',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: _OwlPainter(sleeping)),
  );
}

class _OwlPainter extends CustomPainter {
  _OwlPainter(this.sleeping);
  final bool sleeping;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 88);
    final p = Paint();
    canvas.drawCircle(
      const Offset(44, 44),
      42,
      p..color = const Color(0xFFFFF1C9),
    );
    p.color = const Color(0xFF8B5CF6);
    canvas.drawPath(
      Path()
        ..moveTo(26, 34)
        ..lineTo(30, 22)
        ..lineTo(38, 30)
        ..lineTo(50, 30)
        ..lineTo(58, 22)
        ..lineTo(62, 34)
        ..close(),
      p,
    );
    canvas.drawOval(
      Rect.fromCircle(center: const Offset(44, 50), radius: 20),
      p,
    );
    if (sleeping) {
      final lid = Paint()
        ..color = const Color(0xFF1F1A33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(36, 43), radius: 5),
        0.2,
        math.pi - 0.4,
        false,
        lid,
      );
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(52, 43), radius: 5),
        0.2,
        math.pi - 0.4,
        false,
        lid,
      );
    } else {
      p.color = Colors.white;
      canvas.drawCircle(const Offset(36, 44), 7, p);
      canvas.drawCircle(const Offset(52, 44), 7, p);
      p.color = const Color(0xFF1F1A33);
      canvas.drawCircle(const Offset(37, 45), 3.2, p);
      canvas.drawCircle(const Offset(51, 45), 3.2, p);
    }
    p.color = const Color(0xFFF59E0B);
    canvas.drawPath(
      Path()
        ..moveTo(41, 53)
        ..lineTo(44, 57)
        ..lineTo(47, 53)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(_OwlPainter old) => old.sleeping != sleeping;
}

const avatarColors = [
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
  Color(0xFFEF4444),
];

/// Coloured circle with the student's initial.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.index,
    this.size = 56,
  });

  final String name;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: avatarColors[index % avatarColors.length],
      shape: BoxShape.circle,
    ),
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(
        fontFamily: Fonts.display,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.45,
        color: Colors.white,
        height: 1.1,
      ),
    ),
  );
}
