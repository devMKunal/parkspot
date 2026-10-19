import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

enum StatusTone { success, neutral, danger, highlight }

/// Small status label: "Completed", "Cancelled · refunded", "Happening now".
///
/// Map booking statuses to a tone in the feature layer; this widget only
/// knows colours.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semantic = context.semantic;
    final (bg, fg) = switch (tone) {
      StatusTone.success => (
        semantic.successContainer,
        semantic.onSuccessContainer,
      ),
      StatusTone.neutral => (colors.surfaceContainer, colors.onSurfaceVariant),
      StatusTone.danger => (colors.errorContainer, colors.onErrorContainer),
      StatusTone.highlight => (semantic.accent, semantic.onAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
