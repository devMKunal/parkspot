import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/page_dots.dart';
import 'package:parkspot/features/onboarding/presentation/widgets/onboarding_art.dart';
import 'package:parkspot/router/app_routes.dart';

typedef _Slide = ({OnboardingArtKind art, String title, String body});

const List<_Slide> _slides = [
  (
    art: OnboardingArtKind.findSpot,
    title: 'Find a spot before you leave',
    body:
        'See free slots live at lots near you, so no more circling the '
        'block.',
  ),
  (
    art: OnboardingArtKind.pay,
    title: 'Book & pay in seconds',
    body: 'Pick a time, pay with UPI or card, and the slot is yours.',
  ),
  (
    art: OnboardingArtKind.park,
    title: 'Flash, park, relax',
    body: "Show your pass at the gate. We'll nudge you before time's up.",
  ),
];

/// Three swipeable slides, then sign-up.
///
/// Holds only UI state (the current slide). Leaving, by Skip or the last
/// button, calls [onFinished] once and goes to sign-up; [onFinished] is
/// where the "seen" flag is saved, so the next launch goes to login.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;
  bool _finished = false;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showSlide(int index) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      await _controller.animateToPage(
        index,
        duration: AppDurations.slow,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
    // A deep link waiting behind onboarding survives to sign-up.
    final from = GoRouterState.of(
      context,
    ).uri.queryParameters[AppRoutes.fromParam];
    context.go(AppRoutes.withFrom(AppRoutes.signup, from));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back steps through the slides before leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_showSlide(_index - 1));
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 12, 0),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.onSurfaceVariant,
                      minimumSize: const Size(
                        AppSizes.minTouchTarget,
                        AppSizes.minTouchTarget,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) =>
                      _SlideView(slide: _slides[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.xxxl,
                ),
                child: Row(
                  children: [
                    PageDots(count: _slides.length, index: _index),
                    const Spacer(),
                    ChunkyButton(
                      label: _isLast ? "Let's go" : 'Next',
                      trailingIcon: Icons.arrow_forward_rounded,
                      expand: false,
                      onPressed: _isLast
                          ? _finish
                          : () => unawaited(_showSlide(_index + 1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.md,
        AppSpacing.xxl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Up to the mockup's 340 dp; shrinks first when space is short
          // (small phones, large text).
          Flexible(
            child: SizedBox(
              height: 340,
              width: double.infinity,
              child: OnboardingArt(kind: slide.art),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            slide.title,
            style: context.text.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            slide.body,
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
