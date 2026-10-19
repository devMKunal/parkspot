import 'package:flutter/material.dart';
import 'package:parkspot/core/theme/app_semantic_colors.dart';

extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get text => theme.textTheme;

  /// Throws if the theme wasn't built by `AppTheme`; that's a setup bug
  /// worth failing loudly on.
  AppSemanticColors get semantic => theme.extension<AppSemanticColors>()!;

  bool get isDark => theme.brightness == Brightness.dark;
}
