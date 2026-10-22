import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/dev/dev_session.dart';
import 'package:parkspot/features/splash/presentation/splash_page.dart';
import 'package:parkspot/router/app_router.dart';
import 'package:parkspot/router/auth_status.dart';

void main() {
  late DevSession session;
  late GoRouter router;

  Future<void> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/splash',
    bool onboardingSeen = false,
  }) async {
    session = DevSession(
      restoreDelay: const Duration(seconds: 1),
      onboardingSeen: onboardingSeen,
    );
    router = createAppRouter(
      authStatus: session.status,
      onboardingSeen: session.onboardingSeen,
      initialLocation: initialLocation,
    );
    addTearDown(() {
      router.dispose();
      session.dispose();
    });
    await tester.pumpWidget(
      DevSessionScope(
        session: session,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('first launch: splash, onboarding, sign-up, map', (tester) async {
    await pumpApp(tester);
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(location(), '/onboarding');

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(location(), '/signup');
    expect(session.onboardingSeen.value, isTrue);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(session.status.value, AuthStatus.authenticated);
    expect(location(), '/');
  });

  testWidgets('a deep link survives the splash and login', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/bookings/b1',
      onboardingSeen: true,
    );
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(location(), '/login?from=%2Fbookings%2Fb1');

    await tester.tap(find.widgetWithText(ChunkyButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(location(), '/bookings/b1');
    expect(find.text('Pass b1'), findsWidgets);
  });

  testWidgets('result pages win over the pass route', (tester) async {
    await pumpApp(tester);
    session.signIn();
    await tester.pumpAndSettle();

    router.go('/bookings/b1/paid');
    await tester.pumpAndSettle();
    expect(find.text('Payment successful'), findsWidgets);

    await tester.tap(find.text('Show my pass'));
    await tester.pumpAndSettle();
    expect(location(), '/bookings/b1');
  });

  testWidgets('logging out returns to login', (tester) async {
    await pumpApp(tester, onboardingSeen: true);
    session.signIn();
    await tester.pumpAndSettle();

    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(location(), '/login?from=%2Fprofile');
  });
}
