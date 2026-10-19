import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';

/// A ring that empties as booking time runs out, with any [child] centred.
///
/// Stateless on purpose: the active-booking Cubit owns the clock (a ticker
/// driven by `booking.end`), and passes the fraction left in here.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.remaining,
    required this.semanticLabel,
    this.child,
    this.size = 132,
    this.strokeWidth = 14,
    this.color,
    this.trackColor,
    super.key,
  });

  /// Fraction of the booking left, 0..1.
  final double remaining;

  /// e.g. "1 hour 42 minutes left".
  final String semanticLabel;
  final Widget? child;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            remaining: remaining.clamp(0.0, 1.0),
            color: color ?? context.colors.primary,
            track: trackColor ?? context.colors.primary.withValues(alpha: 0.18),
            strokeWidth: strokeWidth,
          ),
          child: Center(child: ExcludeSemantics(child: child)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.remaining,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double remaining;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = track);
    if (remaining > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * remaining,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.remaining != remaining ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
