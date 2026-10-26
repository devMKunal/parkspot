import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/domain/user.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/splash/presentation/splash_page.dart';
import 'package:parkspot/router/app_router.dart';
import 'package:parkspot/router/auth_status.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() => registerFallbackValue(const GeoPoint(0, 0)));
  late MockAuthRepository repository;
  late AuthBloc auth;
  late InMemoryOnboardingStatus onboarding;
  late GoRouter router;

  setUp(() {
    repository = MockAuthRepository();
    getIt.registerSingleton<AuthRepository>(repository);
    registerQuietMap(getIt);
    when(() => repository.logout()).thenAnswer((_) async {});
  });
  tearDown(getIt.reset);

  Future<void> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/splash',
    bool onboardingSeen = false,
    User? restores,
  }) async {
    when(() => repository.restoreSession()).thenAnswer(
      (_) => Future.delayed(const Duration(seconds: 1), () => restores),
    );
    auth = AuthBloc(
      repository: repository,
      sessionExpired: const Stream.empty(),
    )..add(const AuthSessionRestoreRequested());
    onboarding = InMemoryOnboardingStatus(seen: onboardingSeen);
    final status = StreamValueNotifier(
      auth.stream.map((s) => s.status),
      initial: auth.state.status,
    );
    router = createAppRouter(
      authStatus: status,
      onboarding: onboarding,
      initialLocation: initialLocation,
    );
    addTearDown(() {
      router.dispose();
      status.dispose();
      unawaited(auth.close());
    });
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> fill(WidgetTester tester, List<String> values) async {
    final fields = find.byType(TextFormField);
    for (final (i, value) in values.indexed) {
      await tester.enterText(fields.at(i), value);
    }
  }

  testWidgets('first launch: splash, onboarding, sign-up, map', (tester) async {
    when(
      () => repository.register(
        name: 'Asha',
        email: 'asha@mail.com',
        password: 'secret12',
      ),
    ).thenAnswer((_) async => testUser);
    await pumpApp(tester);
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(location(), '/onboarding');

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(location(), '/signup');
    expect(onboarding.seen.value, isTrue);

    await fill(tester, ['Asha', 'asha@mail.com', 'secret12', 'secret12']);
    await tester.tap(find.widgetWithText(ChunkyButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(auth.state.status, AuthStatus.authenticated);
    expect(location(), '/');
  });

  testWidgets('a deep link survives the splash and login', (tester) async {
    when(
      () => repository.login(email: 'asha@mail.com', password: 'secret12'),
    ).thenAnswer((_) async => testUser);
    await pumpApp(
      tester,
      initialLocation: '/bookings/b1',
      onboardingSeen: true,
    );
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(location(), '/login?from=%2Fbookings%2Fb1');

    // Hopping to sign-up and back keeps the link.
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(location(), '/signup?from=%2Fbookings%2Fb1');
    await tester.tap(find.widgetWithText(TextButton, 'Log in'));
    await tester.pumpAndSettle();

    await fill(tester, ['asha@mail.com', 'secret12']);
    await tester.tap(find.widgetWithText(ChunkyButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(location(), '/bookings/b1');
    expect(find.text('Pass b1'), findsWidgets);
  });

  testWidgets('result pages win over the pass route', (tester) async {
    await pumpApp(tester, restores: testUser);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    router.go('/bookings/b1/paid');
    await tester.pumpAndSettle();
    expect(find.text('Payment successful'), findsWidgets);

    await tester.tap(find.text('Show my pass'));
    await tester.pumpAndSettle();
    expect(location(), '/bookings/b1');
  });

  testWidgets('logging out returns to login', (tester) async {
    await pumpApp(tester, onboardingSeen: true, restores: testUser);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(location(), '/login?from=%2Fprofile');
  });
}
