import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

/// A ticket: rounded card with a half-circle notch cut into each side.
///
/// Used for the price summary, the booking summary and the QR pass.
class TicketCard extends StatelessWidget {
  const TicketCard({
    required this.child,
    this.color,
    this.borderColor,
    this.notchOffset = 0.5,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;

  /// Defaults to the raised card colour.
  final Color? color;

  /// Optional 2 dp outline that follows the notches.
  final Color? borderColor;

  /// Where the notches sit, as a fraction of the height (0..1).
  final double notchOffset;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? context.colors.surfaceContainerLowest,
        shape: TicketShapeBorder(
          notchOffset: notchOffset,
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!, width: 2),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class TicketShapeBorder extends ShapeBorder {
  const TicketShapeBorder({
    this.radius = AppRadius.lg,
    this.notchRadius = 11,
    this.notchOffset = 0.5,
    this.side = BorderSide.none,
  });

  final double radius;
  final double notchRadius;
  final double notchOffset;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final r = math.min(radius, rect.shortestSide / 2);
    final y = rect.top + rect.height * notchOffset.clamp(0.0, 1.0);
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    final notches = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(rect.left, y), radius: notchRadius),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(rect.right, y), radius: notchRadius),
      );
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => TicketShapeBorder(
    radius: radius * t,
    notchRadius: notchRadius * t,
    notchOffset: notchOffset,
    side: side.scale(t),
  );
}

/// The dashed tear line inside a ticket.
class DashedDivider extends StatelessWidget {
  const DashedDivider({this.color, this.dash = 6, this.gap = 5, super.key});

  final Color? color;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(
          color ?? context.colors.outlineVariant,
          dash,
          gap,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color, this.dash, this.gap);

  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.dash != dash || old.gap != gap;
}
