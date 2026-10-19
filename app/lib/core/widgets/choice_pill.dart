import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

/// How a selected pill stands out.
enum ChoicePillEmphasis {
  /// Inverted ink: day picker, map filters, trip tabs.
  neutral,

  /// Primary fill with a press shadow: the picked start time.
  primary,
}

/// A single-select pill. Group several in a [Wrap] or grid and keep the
/// selection in your BLoC/Cubit state.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.emphasis = ChoicePillEmphasis.neutral,
    this.height = 40,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final ChoicePillEmphasis emphasis;

  /// 40 for filter rows, 48 for time-slot grids.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg, border, shadow) = switch ((selected, emphasis)) {
      (true, ChoicePillEmphasis.neutral) => (
        colors.onSurface,
        colors.surface,
        null,
        null,
      ),
      (true, ChoicePillEmphasis.primary) => (
        colors.primary,
        colors.onPrimary,
        null,
        context.semantic.primaryDeep,
      ),
      (false, ChoicePillEmphasis.neutral) => (
        Colors.transparent,
        colors.onSurface,
        colors.outlineVariant,
        null,
      ),
      (false, ChoicePillEmphasis.primary) => (
        colors.surfaceContainer,
        colors.onSurface,
        null,
        null,
      ),
    };
    final radius = BorderRadius.circular(height >= 48 ? 16 : 14);

    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        // Keeps the touch target at 48 dp for the 40 dp visual size.
        padding: EdgeInsets.symmetric(
          vertical: (AppSizes.minTouchTarget - height).clamp(0, 8) / 2,
        ),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          height: height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: border == null ? null : Border.all(color: border, width: 2),
            boxShadow: [
              if (shadow != null)
                BoxShadow(color: shadow, offset: const Offset(0, 3)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onSelected,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: context.text.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
