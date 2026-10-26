import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/widgets/brand_mark.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';

/// The cold-start screen, shown while the session is checked.
///
/// It never navigates: the router's redirect moves the user on as soon as
/// the auth status leaves `unknown`. The colour matches the native launch
/// screen, so there is no flash between the two.
///
/// With [error] (offline at launch) the dots give way to the message and a
/// retry, since the session can't be checked and logging out would be wrong.
class SplashPage extends StatelessWidget {
  const SplashPage({this.error, this.onRetry, super.key});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final onBrand = semantic.onCelebration;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: semantic.celebration,
        body: Center(
          child: Semantics(
            label: 'ParkSpot is loading',
            liveRegion: true,
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 96),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'ParkSpot',
                    style: context.text.displaySmall?.copyWith(color: onBrand),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Parking, sorted.',
                    style: context.text.titleMedium?.copyWith(
                      color: onBrand.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  if (error == null) _LoadingDots(color: onBrand),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: error == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: onBrand),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ChunkyButton(
                      label: 'Try again',
                      variant: ChunkyButtonVariant.accent,
                      onPressed: onRetry,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Three dots that hop in turn. Still when the OS asks for less motion.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.color});

  final Color color;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Transform.translate(
                offset: Offset(0, -6 * _hop(i)),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.5 + 0.5 * _hop(i)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 0 to 1 and back once per cycle, each dot a third of a cycle later.
  double _hop(int i) {
    final t = (_controller.value - i / 3) % 1;
    return t < 0.5 ? math.sin(t * 2 * math.pi) : 0;
  }
}
