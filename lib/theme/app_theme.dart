import 'package:flutter/material.dart';

import 'tokens.dart';

/// Junior (Classes 1–5) and Senior (Classes 6–10) differ in type size, tap
/// target size and corner radius. Screens read these values instead of
/// branching on the class level themselves.
@immutable
class Tier extends ThemeExtension<Tier> {
  const Tier({
    required this.isJunior,
    required this.bodySize,
    required this.titleSize,
    required this.tapTarget,
    required this.primaryButtonHeight,
    required this.radius,
  });

  static const junior = Tier(
    isJunior: true,
    bodySize: 20,
    titleSize: 24,
    tapTarget: 56,
    primaryButtonHeight: 72,
    radius: 24,
  );

  static const senior = Tier(
    isJunior: false,
    bodySize: 16,
    titleSize: 18,
    tapTarget: 48,
    primaryButtonHeight: 52,
    radius: 16,
  );

  final bool isJunior;
  final double bodySize;
  final double titleSize;
  final double tapTarget;
  final double primaryButtonHeight;
  final double radius;

  static Tier of(BuildContext context) =>
      Theme.of(context).extension<Tier>() ?? senior;

  @override
  Tier copyWith() => this;

  @override
  Tier lerp(Tier? other, double t) => t < 0.5 ? this : (other ?? this);
}

ThemeData buildTheme(Tier tier) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: Fonts.body,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.ground,
      onSurface: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.ground,
  );
  return base.copyWith(
    extensions: [tier],
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primaryTint,
      height: tier.isJunior ? 76 : 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: Fonts.body,
          fontWeight: FontWeight.w800,
          fontSize: tier.isJunior ? 15 : 13,
          color: AppColors.ink,
        ),
      ),
    ),
  );
}
