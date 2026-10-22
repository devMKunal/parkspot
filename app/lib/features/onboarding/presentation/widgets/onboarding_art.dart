import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_typography.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/core/widgets/brand_mark.dart';
import 'package:parkspot/core/widgets/countdown_ring.dart';
import 'package:parkspot/core/widgets/lot_marker.dart';

enum OnboardingArtKind { findSpot, pay, park }

/// The illustration card on each onboarding slide, built from the real
/// widgets (markers, ring, brand mark) so it always matches the app.
///
/// Drawn on a fixed 342 x 340 canvas and scaled down to fit, so it never
/// overflows on small phones. Decorative: hidden from screen readers.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({required this.kind, super.key});

  final OnboardingArtKind kind;

  static const _canvas = Size(342, 340);

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final tint = switch (kind) {
      OnboardingArtKind.findSpot => semantic.tintMint,
      OnboardingArtKind.pay => semantic.tintYellow,
      OnboardingArtKind.park => semantic.tintViolet,
    };
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: ColoredBox(
          color: tint,
          child: FittedBox(
            child: SizedBox.fromSize(
              size: _canvas,
              child: Stack(
                clipBehavior: Clip.none,
                children: switch (kind) {
                  OnboardingArtKind.findSpot => _findSpot(context),
                  OnboardingArtKind.pay => _pay(context),
                  OnboardingArtKind.park => _park(context, tint),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _findSpot(BuildContext context) {
    final road = context.colors.surface;
    final primary = context.colors.primary;
    return [
      Positioned(
        left: -20,
        top: 150,
        child: _Road(color: road, length: 440, angle: -0.17),
      ),
      Positioned(
        left: -30,
        top: 160,
        child: _Road(color: road, length: 400, angle: 1.4),
      ),
      const Positioned(
        left: 60,
        top: 70,
        child: LotMarker(freeSlots: 37, totalSlots: 120),
      ),
      const Positioned(
        left: 220,
        top: 60,
        child: LotMarker(freeSlots: 2, totalSlots: 40),
      ),
      const Positioned(
        left: 190,
        top: 180,
        child: LotMarker(freeSlots: 6, totalSlots: 40, selected: true),
      ),
      // You are here.
      Positioned(
        left: 110,
        top: 250,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
            border: Border.all(color: road, width: 4),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.2),
                spreadRadius: 16,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _pay(BuildContext context) {
    final colors = context.colors;
    final ink = context.semantic.markerOutline;
    return [
      Positioned(
        left: 50,
        top: 60,
        child: Transform.rotate(
          angle: -0.09,
          child: Container(
            width: 240,
            height: 210,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: ink, width: 3),
              boxShadow: [BoxShadow(color: ink, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Total',
                  style: context.text.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  Formatters.money(const Money(8000)),
                  style: context.text.displayMedium?.copyWith(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Pay',
                    style: context.text.titleMedium?.copyWith(
                      color: colors.onPrimary,
                      fontFamily: AppTypography.display,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 30,
        top: 30,
        child: BrandMark(
          size: 72,
          tilt: 0.21,
          child: Icon(
            Icons.check_rounded,
            size: 44,
            color: context.semantic.onAccent,
          ),
        ),
      ),
    ];
  }

  List<Widget> _park(BuildContext context, Color tint) {
    final semantic = context.semantic;
    return [
      Positioned(
        left: 71,
        top: 50,
        child: CountdownRing(
          remaining: 0.7,
          size: 200,
          strokeWidth: 22,
          semanticLabel: '',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1:42',
                style: context.text.displaySmall?.copyWith(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              Text(
                'left',
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        right: 36,
        bottom: 36,
        child: Transform.rotate(
          angle: -0.1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: semantic.accent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: semantic.markerOutline, width: 3),
            ),
            child: Text(
              '15 min left!',
              style: context.text.titleSmall?.copyWith(
                color: semantic.onAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _Road extends StatelessWidget {
  const _Road({required this.color, required this.length, required this.angle});

  final Color color;
  final double length;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: length,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );
  }
}
