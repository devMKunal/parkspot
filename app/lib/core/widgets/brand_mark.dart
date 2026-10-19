import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_typography.dart';

/// The tilted yellow "P" tile: splash, auth headers, success badge.
///
/// With [child] it shows that instead of the P (e.g. a check icon on the
/// payment success screen).
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 56, this.tilt = -0.1, this.child, super.key});

  final double size;

  /// Rotation in radians; about -6 degrees by default.
  final double tilt;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: tilt,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: semantic.accent,
            borderRadius: BorderRadius.circular(size / 3),
            boxShadow: [
              BoxShadow(
                color: semantic.accentDeep,
                offset: Offset(0, size / 15),
              ),
            ],
          ),
          child:
              child ??
              Text(
                'P',
                style: TextStyle(
                  fontFamily: AppTypography.display,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.62,
                  height: 1,
                  color: semantic.onAccent,
                ),
              ),
        ),
      ),
    );
  }
}
