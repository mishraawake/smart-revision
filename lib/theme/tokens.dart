import 'package:flutter/material.dart';

import '../models/deck.dart';

/// Colours from the Phase 1 design system board.
abstract final class AppColors {
  static const primary = Color(0xFF4338CA);
  static const primaryDark = Color(0xFF312E81);
  static const primaryTint = Color(0xFFE0E7FF);
  static const onPrimaryTint = Color(0xFF3730A3);

  static const ground = Color(0xFFFFF7EC);
  static const groundBorder = Color(0xFFE9DCC8);
  static const cardShadow = Color(0xFFF3DFC4);
  static const chip = Color(0xFFF3EADB);
  static const ink = Color(0xFF1F1A33);
  static const inkMuted = Color(0xFF5B5470);

  static const star = Color(0xFFF5B700);
  static const starStroke = Color(0xFFB45309);
  static const starBg = Color(0xFFFEF3C7);
  static const starInk = Color(0xFF92400E);

  static const streak = Color(0xFFDC2626);
  static const streakBg = Color(0xFFFEE2E2);
  static const streakInk = Color(0xFF991B1B);

  // "Knew it" is filled and dark; "Didn't know" is tinted and light so the
  // two differ in lightness for colour-blind students.
  static const knew = Color(0xFF13804A);
  static const knewInk = Color(0xFF14532D);
  static const again = Color(0xFFFFE3CC);
  static const againBorder = Color(0xFFC2410C);
  static const againInk = Color(0xFF9A3412);

  static const progressTrack = Color(0xFFCFC6EE);
}

class SubjectStyle {
  const SubjectStyle(this.background, this.foreground, this.glyph);

  final Color background;
  final Color foreground;
  final String glyph;

  static const _styles = {
    'english': SubjectStyle(Color(0xFFDBEAFE), Color(0xFF1E40AF), 'Ab'),
    'maths': SubjectStyle(Color(0xFFEDE9FE), Color(0xFF5B21B6), '12+'),
    'evs': SubjectStyle(Color(0xFFCCFBF1), Color(0xFF115E59), 'EVS'),
    'science': SubjectStyle(Color(0xFFCFFAFE), Color(0xFF155E75), 'Sc'),
    'social': SubjectStyle(Color(0xFFFEF3C7), Color(0xFF92400E), 'SS'),
  };

  /// Looks set in the content sheet; they win over the built-in ones.
  static final _fromDeck = <String, SubjectStyle>{};

  static SubjectStyle of(String subjectId) =>
      _fromDeck[subjectId] ??
      _styles[subjectId] ??
      const SubjectStyle(AppColors.primaryTint, AppColors.onPrimaryTint, '•');

  /// Uses a subject's colours and glyph from its deck. Missing parts keep
  /// the built-in look.
  static void useDeck(Subject s) {
    if (s.colour == null && s.ink == null && s.glyph == null) return;
    final base = of(s.id);
    _fromDeck[s.id] = SubjectStyle(
      s.colour == null ? base.background : Color(s.colour!),
      s.ink == null ? base.foreground : Color(s.ink!),
      s.glyph ?? base.glyph,
    );
  }
}

abstract final class Fonts {
  static const display = 'Baloo2';
  static const body = 'Nunito';
}

/// The grown-up screens (sign-in, parent, teacher, settings): same indigo,
/// a neutral ground, 1px lines instead of coloured shadows.
abstract final class AdultColors {
  static const ground = Color(0xFFF6F4EF);
  static const line = Color(0xFFE6E1D7);
  static const field = Color(0xFFCFC8BA);
  static const chip = Color(0xFFEFEBE3);
  static const chipInk = Color(0xFF3D3654);

  static const mastered = Color(0xFFDCFCE7);
  static const masteredInk = Color(0xFF14532D);
  static const needsWork = Color(0xFFFFEDD5);
  static const needsWorkInk = Color(0xFF9A3412);
}
