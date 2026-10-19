import 'package:flutter/material.dart';

/// Raw palette. Only `core/theme` reads this file; widgets go through
/// `Theme.of(context)` (see `context_x.dart`) so dark mode can't be skipped.
abstract final class AppColors {
  static const seed = Color(0xFF4F46E5);

  // Light
  static const primaryLight = Color(0xFF4F46E5);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFF7F6FF);
  static const cardLight = Color(0xFFFFFFFF);
  static const containerLight = Color(0xFFEFEEFB);
  static const onSurfaceLight = Color(0xFF17152B);
  static const onSurfaceVariantLight = Color(0xFF4A4766);
  static const outlineVariantLight = Color(0xFFD3D1E6);
  static const errorLight = Color(0xFFC4262E);
  static const errorContainerLight = Color(0xFFFFE1E1);
  static const onErrorContainerLight = Color(0xFF5C0A0E);

  // Dark
  static const primaryDark = Color(0xFFA5A0FF);
  static const onPrimaryDark = Color(0xFF16114F);
  static const surfaceDark = Color(0xFF110F1F);
  static const cardDark = Color(0xFF1C1A2E);
  static const containerDark = Color(0xFF24223A);
  static const onSurfaceDark = Color(0xFFEEECFF);
  static const onSurfaceVariantDark = Color(0xFFC3C0DC);
  static const outlineVariantDark = Color(0xFF3C3956);
  static const errorDark = Color(0xFFFF9A9A);
  static const errorContainerDark = Color(0xFF4A1518);
  static const onErrorContainerDark = Color(0xFFFFDAD9);

  // Brand accent: the same sunshine yellow in both themes.
  static const accent = Color(0xFFFFC83D);
  static const onAccent = Color(0xFF2B2100);
}
