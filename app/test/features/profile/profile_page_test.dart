import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/core/theme/theme_mode_controller.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/profile/presentation/profile_page.dart';

import '../../helpers/mocks.dart';
import '../../helpers/prefs.dart';
import '../../helpers/pump_themed.dart';

void main() {
  late MockAuthBloc auth;
  late ThemeModeController theme;

  setUp(() async {
    auth = MockAuthBloc();
    when(() => auth.state).thenReturn(AuthState.authenticated(testUser));
    theme = ThemeModeController(await testPrefs());
  });

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.usePhoneSize();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: ProfilePage(themeMode: theme),
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets('shows who is signed in (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pump(tester, dark: dark);

      expect(find.text('Asha'), findsOneWidget);
      expect(find.text('asha@mail.com'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('My trips'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('appearance switches the theme', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(theme.value, ThemeMode.dark);
  });

  testWidgets('log out tells AuthBloc', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Log out'));
    verify(() => auth.add(const AuthLogoutRequested())).called(1);
  });
}
