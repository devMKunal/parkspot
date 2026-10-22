import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/features/onboarding/presentation/onboarding_page.dart';

void main() {
  late int finished;
  late GoRouter router;

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    String location = '/onboarding',
    bool dark = false,
  }) async {
    finished = 0;
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) =>
              OnboardingPage(onFinished: () => finished++),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const Text('Sign-up page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('Next walks the slides, then the last button signs up', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    expect(find.text('Find a spot before you leave'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Book & pay in seconds'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Flash, park, relax'), findsOneWidget);
    expect(finished, 0);

    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(location(), '/signup');
  });

  testWidgets('swiping moves the dots', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Book & pay in seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Skip finishes once and keeps a pending deep link', (
    tester,
  ) async {
    await pumpOnboarding(tester, location: '/onboarding?from=%2Ftrips');

    await tester.tap(find.text('Skip'));
    await tester.tap(find.text('Skip'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(location(), '/signup?from=%2Ftrips');
  });

  testWidgets('back goes to the previous slide', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Find a spot before you leave'), findsOneWidget);
  });

  // Any overflow on a small phone with large text fails the test.
  for (final dark in [false, true]) {
    testWidgets('fits a small phone at 130% text '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      tester.view.physicalSize = const Size(320, 568) * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpOnboarding(tester, dark: dark);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
