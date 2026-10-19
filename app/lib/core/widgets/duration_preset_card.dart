import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

/// A named duration choice: "Shopping spree · 2 h".
class DurationPresetCard extends StatelessWidget {
  const DurationPresetCard({
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// The playful name, e.g. "Coffee & catch-up".
  final String title;

  /// The duration as shown, e.g. `Formatters.duration(...)`.
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          color: selected
              ? context.semantic.tintViolet
              : colors.surfaceContainer,
          borderRadius: radius,
          border: Border.all(
            color: selected ? colors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(color: colors.primary, offset: const Offset(0, 3)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md + 2,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(value, style: context.text.titleLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
