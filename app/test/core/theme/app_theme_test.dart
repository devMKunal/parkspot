import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/theme/app_colors.dart';
import 'package:parkspot/core/theme/app_semantic_colors.dart';
import 'package:parkspot/core/theme/app_theme.dart';

void main() {
  test('both themes carry the semantic colours', () {
    expect(
      AppTheme.light().extension<AppSemanticColors>(),
      AppSemanticColors.light,
    );
    expect(
      AppTheme.dark().extension<AppSemanticColors>(),
      AppSemanticColors.dark,
    );
  });

  test('pins the brand roles over the seeded scheme', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.colorScheme.primary, AppColors.primaryLight);
    expect(light.colorScheme.surface, AppColors.surfaceLight);
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, AppColors.primaryDark);
  });

  test('semantic colours lerp field by field', () {
    final mid = AppSemanticColors.light.lerp(AppSemanticColors.dark, 0.5);
    expect(
      mid.primaryDeep,
      Color.lerp(
        AppSemanticColors.light.primaryDeep,
        AppSemanticColors.dark.primaryDeep,
        0.5,
      ),
    );
  });
}
