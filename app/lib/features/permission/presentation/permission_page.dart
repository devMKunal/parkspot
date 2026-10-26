import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/location/location_service.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/fill_scroll_view.dart';
import 'package:parkspot/router/app_routes.dart';

/// Why we ask, shown once before the OS prompt. Pops `true` when location
/// was granted, `false` for "Not now" (the map then focuses search).
class PermissionPage extends StatefulWidget {
  const PermissionPage({this.location, super.key});

  /// Defaults to the app's; tests pass a mock.
  final LocationService? location;

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  late final LocationService _location =
      widget.location ?? getIt<LocationService>();
  bool _asking = false;

  Future<void> _allow() async {
    setState(() => _asking = true);
    final granted = await _location.request();
    if (mounted) _leave(granted: granted);
  }

  Future<void> _skip() async {
    await _location.skip();
    if (mounted) _leave(granted: false);
  }

  /// Back to the map; opened by deep link there's nothing to pop.
  void _leave({required bool granted}) =>
      context.canPop() ? context.pop(granted) : context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FillScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxxl * 2,
            AppSpacing.xxl,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              const _PinArt(),
              const SizedBox(height: AppSpacing.xxl + 4),
              Text(
                'Can we see where you are?',
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                'We use your location only to show lots near you and guide '
                'you there. Nothing is tracked in the background.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              ChunkyButton(
                label: 'Allow location',
                loading: _asking,
                onPressed: _allow,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: TextButton(
                  onPressed: _asking ? null : _skip,
                  child: const Text("Not now, I'll search"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A map pin in two rings, with a "412 m" tag.
class _PinArt extends StatelessWidget {
  const _PinArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semantic = context.semantic;
    final ink = semantic.markerOutline;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: semantic.tintViolet,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(34),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
            Transform.rotate(
              angle: -0.785,
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  border: Border.all(color: ink, width: 4),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(42),
                    topRight: Radius.circular(42),
                    bottomRight: Radius.circular(42),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: semantic.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: ink, width: 3),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 26,
              child: Transform.rotate(
                angle: 0.14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: semantic.availabilityHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ink, width: 2),
                  ),
                  child: Text(
                    '412 m',
                    style: context.text.labelLarge?.copyWith(
                      color: semantic.onAvailabilityHigh,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
