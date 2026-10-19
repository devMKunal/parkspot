import 'package:flutter/material.dart';
import 'package:parkspot/core/theme/app_colors.dart';
import 'package:parkspot/core/theme/app_semantic_colors.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/theme/app_typography.dart';

/// Light and dark [ThemeData] from one builder, so the two can't drift.
abstract final class AppTheme {
  static ThemeData light() => _build(_lightScheme(), AppSemanticColors.light);
  static ThemeData dark() => _build(_darkScheme(), AppSemanticColors.dark);

  // fromSeed fills every role; the overrides pin the ones the design sets by
  // hand, because the generated tones are more muted than the mockups.
  // surfaceContainerLowest is the raised card colour in both themes.
  static ColorScheme _lightScheme() =>
      ColorScheme.fromSeed(seedColor: AppColors.seed).copyWith(
        primary: AppColors.primaryLight,
        onPrimary: AppColors.onPrimaryLight,
        surface: AppColors.surfaceLight,
        surfaceContainerLowest: AppColors.cardLight,
        surfaceContainer: AppColors.containerLight,
        onSurface: AppColors.onSurfaceLight,
        onSurfaceVariant: AppColors.onSurfaceVariantLight,
        outlineVariant: AppColors.outlineVariantLight,
        error: AppColors.errorLight,
        errorContainer: AppColors.errorContainerLight,
        onErrorContainer: AppColors.onErrorContainerLight,
      );

  static ColorScheme _darkScheme() =>
      ColorScheme.fromSeed(
        seedColor: AppColors.seed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.primaryDark,
        onPrimary: AppColors.onPrimaryDark,
        surface: AppColors.surfaceDark,
        surfaceContainerLowest: AppColors.cardDark,
        surfaceContainer: AppColors.containerDark,
        onSurface: AppColors.onSurfaceDark,
        onSurfaceVariant: AppColors.onSurfaceVariantDark,
        outlineVariant: AppColors.outlineVariantDark,
        error: AppColors.errorDark,
        errorContainer: AppColors.errorContainerDark,
        onErrorContainer: AppColors.onErrorContainerDark,
      );

  static ThemeData _build(ColorScheme scheme, AppSemanticColors semantic) {
    final text = AppTypography.textTheme();
    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    OutlineInputBorder field(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: 2),
    );

    return ThemeData(
      colorScheme: scheme,
      textTheme: text,
      fontFamily: AppTypography.body,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          textStyle: text.labelLarge,
          shape: roundedMd,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          textStyle: text.labelLarge,
          shape: roundedMd,
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          textStyle: text.labelLarge,
          shape: roundedMd,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        border: field(scheme.outlineVariant),
        enabledBorder: field(scheme.outlineVariant),
        focusedBorder: field(scheme.primary),
        errorBorder: field(scheme.error),
        focusedErrorBorder: field(scheme.error),
        disabledBorder: field(scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: roundedMd,
        backgroundColor: scheme.onSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.surface),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 2,
        space: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainer,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}
