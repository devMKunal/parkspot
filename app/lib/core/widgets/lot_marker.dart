import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/theme/app_typography.dart';
import 'package:parkspot/core/utils/availability.dart';

/// The map pin: a yellow "P" badge plus the free-slot count, coloured by
/// availability, with a pointer underneath.
///
/// google_maps_flutter draws markers natively, so on the map this widget is
/// rendered to a bitmap (e.g. a RepaintBoundary to `BitmapDescriptor.bytes`,
/// cached per count/level/selected). It's a widget so the same look works
/// in lists, the gallery and widget tests.
class LotMarker extends StatelessWidget {
  const LotMarker({
    required this.freeSlots,
    required this.totalSlots,
    this.selected = false,
    super.key,
  });

  final int freeSlots;
  final int totalSlots;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final level = Availability.fromCounts(free: freeSlots, total: totalSlots);
    final (:fill, :onFill) = semantic.availability(level);
    final outline = semantic.markerOutline;
    final count = level == Availability.full ? 'Full' : '$freeSlots';

    return Semantics(
      label: level == Availability.full ? 'Lot full' : '$freeSlots free slots',
      selected: selected,
      child: AnimatedScale(
        scale: selected ? 1.25 : 1,
        duration: AppDurations.medium,
        curve: Curves.easeOutBack,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: outline, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x2E000000), offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PBadge(color: semantic.accent, ink: semantic.onAccent),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    count,
                    style: context.text.labelLarge?.copyWith(
                      color: onFill,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(14, 8),
              painter: _PointerPainter(outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PBadge extends StatelessWidget {
  const _PBadge({required this.color, required this.ink});

  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'P',
        style: TextStyle(
          fontFamily: AppTypography.display,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1,
          color: ink,
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => old.color != color;
}
