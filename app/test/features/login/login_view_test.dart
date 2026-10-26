import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/login/presentation/bloc/login_bloc.dart';
import 'package:parkspot/features/login/presentation/screen/login_page.dart';

import '../../helpers/mocks.dart';
import '../../helpers/pump_themed.dart';

class MockLoginBloc extends MockBloc<LoginEvent, LoginState>
    implements LoginBloc {}

void main() {
  late MockLoginBloc bloc;
  late MockAuthBloc auth;

  setUp(() {
    bloc = MockLoginBloc();
    auth = MockAuthBloc();
    when(() => bloc.state).thenReturn(const LoginState());
    when(() => auth.state).thenReturn(const AuthState.unauthenticated());
  });

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.usePhoneSize();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<LoginBloc>.value(value: bloc),
          ],
          child: LoginView(onSignUp: () {}),
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets('renders the design (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pump(tester, dark: dark);

      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Your spot missed you'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sends email and password', (tester) async {
    await pump(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'asha@mail.com');
    await tester.enterText(fields.at(1), 'secret12');
    await tester.tap(find.widgetWithText(ChunkyButton, 'Log in'));

    verify(
      () => bloc.add(
        const LoginSubmitted(email: 'asha@mail.com', password: 'secret12'),
      ),
    ).called(1);
  });

  testWidgets('wrong password state', (tester) async {
    when(() => bloc.state).thenReturn(
      const LoginState(
        status: SubmitStatus.failure,
        error: LoginBloc.wrongCredentials,
        wrongPassword: true,
      ),
    );
    await pump(tester);

    expect(
      find.widgetWithText(AlertBanner, LoginBloc.wrongCredentials),
      findsOneWidget,
    );
    expect(find.text('Check your password'), findsOneWidget);
  });

  testWidgets('hands the user to AuthBloc', (tester) async {
    whenListen(
      bloc,
      Stream.value(LoginState(status: SubmitStatus.success, user: testUser)),
      initialState: const LoginState(),
    );
    await pump(tester);
    await tester.pump();

    verify(() => auth.add(AuthLoggedIn(testUser))).called(1);
  });
}
