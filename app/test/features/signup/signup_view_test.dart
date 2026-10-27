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
import 'package:parkspot/features/signup/presentation/bloc/signup_bloc.dart';
import 'package:parkspot/features/signup/presentation/screen/signup_page.dart';

import '../../helpers/mocks.dart';

class MockSignupBloc extends MockBloc<SignupEvent, SignupState>
    implements SignupBloc {}

void main() {
  late MockSignupBloc bloc;
  late MockAuthBloc auth;
  late int logInTaps;

  setUp(() {
    bloc = MockSignupBloc();
    auth = MockAuthBloc();
    logInTaps = 0;
    when(() => bloc.state).thenReturn(const SignupState());
    when(() => auth.state).thenReturn(const AuthState.unauthenticated());
  });

  Future<void> pump(WidgetTester tester, {bool dark = false}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<SignupBloc>.value(value: bloc),
            ],
            child: SignupView(onLogIn: () => logInTaps++),
          ),
        ),
      );

  const labels = ['Your name', 'Email', 'Password', 'Confirm password'];
  Finder field(String label) =>
      find.byType(TextFormField).at(labels.indexOf(label));

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ChunkyButton, 'Create account'));
    await tester.pump();
  }

  for (final dark in [false, true]) {
    testWidgets('renders the design copy (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pump(tester, dark: dark);

      expect(find.text("Let's get you parked"), findsOneWidget);
      expect(find.text('Create your account in under a minute.'), findsOne);
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('validates before sending anything', (tester) async {
    await pump(tester);
    await tapCreate(tester);

    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter a password'), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('sends the form and shows the strength hint', (tester) async {
    await pump(tester);
    await tester.enterText(field('Your name'), 'Asha');
    await tester.enterText(field('Email'), 'asha@mail.com');
    await tester.enterText(field('Password'), 'secret12');
    await tester.pump();
    expect(find.text('8+ characters, nice and strong'), findsOneWidget);

    await tester.enterText(field('Confirm password'), 'secret13');
    await tapCreate(tester);
    expect(find.text("Passwords don't match"), findsOneWidget);

    await tester.enterText(field('Confirm password'), 'secret12');
    await tapCreate(tester);
    verify(
      () => bloc.add(
        const CreateAccountEvent(
          name: 'Asha',
          email: 'asha@mail.com',
          password: 'secret12',
        ),
      ),
    ).called(1);
  });

  testWidgets('shows a taken email under the field, other errors on top', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const SignupState(
        status: SubmitStatus.failure,
        emailError: 'An account with this email already exists',
        error: 'Offline',
      ),
    );
    await pump(tester);

    expect(find.text('An account with this email already exists'), findsOne);
    expect(find.widgetWithText(AlertBanner, 'Offline'), findsOneWidget);
  });

  testWidgets('hands the new user to AuthBloc', (tester) async {
    whenListen(
      bloc,
      Stream.value(SignupState(status: SubmitStatus.success, user: testUser)),
      initialState: const SignupState(),
    );
    await pump(tester);
    await tester.pump();

    verify(() => auth.add(AuthLoggedIn(testUser))).called(1);
  });

  testWidgets('Log in link', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Log in'));
    expect(logInTaps, 1);
  });

  setUpAll(
    () => registerFallbackValue(
      const CreateAccountEvent(name: '', email: '', password: ''),
    ),
  );
}
