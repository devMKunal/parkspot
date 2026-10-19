import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/utils/availability.dart';

/// "Loads of space" / "Filling up" / "Almost full" / "Full".
class AvailabilityBadge extends StatelessWidget {
  const AvailabilityBadge({required this.level, this.label, super.key});

  final Availability level;

  /// Overrides the default wording for [level].
  final String? label;

  static String defaultLabel(Availability level) => switch (level) {
    Availability.high => 'Loads of space',
    Availability.medium => 'Filling up',
    Availability.low => 'Almost full',
    Availability.full => 'Full',
  };

  @override
  Widget build(BuildContext context) {
    final (:fill, :onFill) = context.semantic.availability(level);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: onFill, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            label ?? defaultLabel(level),
            style: context.text.labelMedium?.copyWith(
              color: onFill,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
