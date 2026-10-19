import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

enum AlertTone { error, warning, success }

/// An inline message above a form or summary, e.g. "That email and password
/// don't match." Announced by screen readers when it appears.
///
/// Keep wording plain here: this is where errors and money live.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    required this.message,
    this.tone = AlertTone.error,
    super.key,
  });

  final String message;
  final AlertTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semantic = context.semantic;
    final (bg, fg, icon) = switch (tone) {
      AlertTone.error => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      AlertTone.warning => (
        semantic.tintYellow,
        colors.onSurface,
        Icons.schedule_rounded,
      ),
      AlertTone.success => (
        semantic.successContainer,
        semantic.onSuccessContainer,
        Icons.check_circle_outline_rounded,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
