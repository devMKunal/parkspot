import 'package:flutter/widgets.dart';

/// 4-pt spacing scale.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal padding of every screen.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: xl);
}

/// Generous corners are part of the friendly look.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 28;
  static const double sheet = 32;
}

abstract final class AppSizes {
  /// UX bar: every tappable thing is at least 48 dp.
  static const double minTouchTarget = 48;
  static const double buttonHeight = 60;
  static const double fieldHeight = 52;

  /// Depth of the solid bottom shadow; a chunky button sinks by this much.
  static const double pressDepth = 5;
  static const double qrSize = 176;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}
