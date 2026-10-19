import 'package:flutter/material.dart';
import 'package:parkspot/core/theme/app_colors.dart';
import 'package:parkspot/core/utils/availability.dart';

/// App meanings that Material's [ColorScheme] has no slot for.
///
/// Registered on [ThemeData.extensions]; read it with `context.semantic`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.accent,
    required this.onAccent,
    required this.accentDeep,
    required this.primaryDeep,
    required this.availabilityHigh,
    required this.onAvailabilityHigh,
    required this.availabilityMedium,
    required this.onAvailabilityMedium,
    required this.availabilityLow,
    required this.onAvailabilityLow,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.tintViolet,
    required this.tintYellow,
    required this.tintMint,
    required this.markerOutline,
    required this.celebration,
    required this.onCelebration,
  });

  /// Brand yellow: the "P" badge, celebration buttons, Extend.
  final Color accent;
  final Color onAccent;

  /// Solid "press" shadow under accent buttons.
  final Color accentDeep;

  /// Solid "press" shadow under primary buttons.
  final Color primaryDeep;

  final Color availabilityHigh;
  final Color onAvailabilityHigh;
  final Color availabilityMedium;
  final Color onAvailabilityMedium;
  final Color availabilityLow;
  final Color onAvailabilityLow;

  /// Text and icons that confirm something went well.
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Soft fills for stat tiles, tickets and illustrations.
  final Color tintViolet;
  final Color tintYellow;
  final Color tintMint;

  /// Outline around map markers, so they read on any map tile.
  final Color markerOutline;

  /// Full-bleed background of "You're parked!" and the splash.
  final Color celebration;
  final Color onCelebration;

  static const light = AppSemanticColors(
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    accentDeep: Color(0xFFC99400),
    primaryDeep: Color(0xFF3730A3),
    availabilityHigh: Color(0xFF08875D),
    onAvailabilityHigh: Color(0xFFFFFFFF),
    availabilityMedium: Color(0xFFFFC83D),
    onAvailabilityMedium: Color(0xFF3A2A00),
    availabilityLow: Color(0xFFFF6B6B),
    onAvailabilityLow: Color(0xFF3D0808),
    success: Color(0xFF08875D),
    successContainer: Color(0xFFDDF7EA),
    onSuccessContainer: Color(0xFF05583C),
    tintViolet: Color(0xFFEEEBFF),
    tintYellow: Color(0xFFFFF4D6),
    tintMint: Color(0xFFDDF7EA),
    markerOutline: Color(0xFF17152B),
    celebration: Color(0xFF4F46E5),
    onCelebration: Color(0xFFFFFFFF),
  );

  static const dark = AppSemanticColors(
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    accentDeep: Color(0xFFA87C00),
    primaryDeep: Color(0xFF6C63D9),
    availabilityHigh: Color(0xFF3DDC97),
    onAvailabilityHigh: Color(0xFF053B26),
    availabilityMedium: Color(0xFFFFC83D),
    onAvailabilityMedium: Color(0xFF3A2A00),
    availabilityLow: Color(0xFFFF8A8A),
    onAvailabilityLow: Color(0xFF3D0808),
    success: Color(0xFF3DDC97),
    successContainer: Color(0xFF143B2A),
    onSuccessContainer: Color(0xFF9FEFC9),
    tintViolet: Color(0xFF2A2650),
    tintYellow: Color(0xFF3A3015),
    tintMint: Color(0xFF143B2A),
    markerOutline: Color(0xFF0A0914),
    celebration: Color(0xFF2A2480),
    onCelebration: Color(0xFFF2F0FF),
  );

  /// Fill and foreground for an [Availability] level. `full` shares the low
  /// colours; the marker shows "Full" so it never relies on colour alone.
  ({Color fill, Color onFill}) availability(Availability level) =>
      switch (level) {
        Availability.high => (
          fill: availabilityHigh,
          onFill: onAvailabilityHigh,
        ),
        Availability.medium => (
          fill: availabilityMedium,
          onFill: onAvailabilityMedium,
        ),
        Availability.low ||
        Availability.full => (fill: availabilityLow, onFill: onAvailabilityLow),
      };

  @override
  AppSemanticColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentDeep,
    Color? primaryDeep,
    Color? availabilityHigh,
    Color? onAvailabilityHigh,
    Color? availabilityMedium,
    Color? onAvailabilityMedium,
    Color? availabilityLow,
    Color? onAvailabilityLow,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? tintViolet,
    Color? tintYellow,
    Color? tintMint,
    Color? markerOutline,
    Color? celebration,
    Color? onCelebration,
  }) {
    return AppSemanticColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentDeep: accentDeep ?? this.accentDeep,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      availabilityHigh: availabilityHigh ?? this.availabilityHigh,
      onAvailabilityHigh: onAvailabilityHigh ?? this.onAvailabilityHigh,
      availabilityMedium: availabilityMedium ?? this.availabilityMedium,
      onAvailabilityMedium: onAvailabilityMedium ?? this.onAvailabilityMedium,
      availabilityLow: availabilityLow ?? this.availabilityLow,
      onAvailabilityLow: onAvailabilityLow ?? this.onAvailabilityLow,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      tintViolet: tintViolet ?? this.tintViolet,
      tintYellow: tintYellow ?? this.tintYellow,
      tintMint: tintMint ?? this.tintMint,
      markerOutline: markerOutline ?? this.markerOutline,
      celebration: celebration ?? this.celebration,
      onCelebration: onCelebration ?? this.onCelebration,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentDeep: l(accentDeep, other.accentDeep),
      primaryDeep: l(primaryDeep, other.primaryDeep),
      availabilityHigh: l(availabilityHigh, other.availabilityHigh),
      onAvailabilityHigh: l(onAvailabilityHigh, other.onAvailabilityHigh),
      availabilityMedium: l(availabilityMedium, other.availabilityMedium),
      onAvailabilityMedium: l(onAvailabilityMedium, other.onAvailabilityMedium),
      availabilityLow: l(availabilityLow, other.availabilityLow),
      onAvailabilityLow: l(onAvailabilityLow, other.onAvailabilityLow),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      onSuccessContainer: l(onSuccessContainer, other.onSuccessContainer),
      tintViolet: l(tintViolet, other.tintViolet),
      tintYellow: l(tintYellow, other.tintYellow),
      tintMint: l(tintMint, other.tintMint),
      markerOutline: l(markerOutline, other.markerOutline),
      celebration: l(celebration, other.celebration),
      onCelebration: l(onCelebration, other.onCelebration),
    );
  }
}
