import 'package:flutter/material.dart';

/// Two bundled families: Bricolage Grotesque gives display, headline and
/// title roles their playful voice; Plus Jakarta Sans keeps body text, forms
/// and prices easy to read.
abstract final class AppTypography {
  static const display = 'BricolageGrotesque';
  static const body = 'PlusJakartaSans';

  /// Digits that keep their width, for countdowns and prices that tick.
  static const tabular = [FontFeature.tabularFigures()];

  /// Sizes and weights only. [ThemeData] merges this over its own defaults,
  /// which supply the colours for each brightness.
  static TextTheme textTheme() {
    final base = Typography.englishLike2021.apply(fontFamily: body);
    TextStyle loud(TextStyle? s, {double? height}) => s!.copyWith(
      fontFamily: display,
      fontWeight: FontWeight.w800,
      height: height,
      letterSpacing: 0,
    );

    return base.copyWith(
      displayLarge: loud(base.displayLarge, height: 1.05),
      displayMedium: loud(base.displayMedium, height: 1.05),
      displaySmall: loud(base.displaySmall, height: 1.1),
      headlineLarge: loud(base.headlineLarge, height: 1.1),
      headlineMedium: loud(base.headlineMedium, height: 1.15),
      headlineSmall: loud(base.headlineSmall, height: 1.15),
      titleLarge: loud(base.titleLarge),
      titleMedium: base.titleMedium!.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall!.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.labelLarge!.copyWith(fontWeight: FontWeight.w700),
      labelMedium: base.labelMedium!.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
