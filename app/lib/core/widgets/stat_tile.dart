import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

enum StatTileTint { violet, yellow, mint }

/// A small coloured fact, e.g. Price ₹40/hr, Away 412 m, Free 37/120.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.unit,
    this.tint = StatTileTint.violet,
    super.key,
  });

  final String label;
  final String value;

  /// Smaller suffix after [value], e.g. "/hr".
  final String? unit;
  final StatTileTint tint;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final bg = switch (tint) {
      StatTileTint.violet => semantic.tintViolet,
      StatTileTint.yellow => semantic.tintYellow,
      StatTileTint.mint => semantic.tintMint,
    };
    final valueStyle = context.text.titleLarge?.copyWith(fontSize: 22);

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: context.text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ],
        ),
      ),
    );
  }
}
