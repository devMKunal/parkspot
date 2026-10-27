import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/app.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/splash/presentation/splash_page.dart';

import 'helpers/mocks.dart';

void main() {
  testWidgets('boots to the splash, then onboarding on first launch', (
    tester,
  ) async {
    final repository = MockAuthRepository();
    when(
      repository.restoreSession,
    ).thenAnswer((_) => Future.delayed(const Duration(seconds: 1), () => null));
    final auth = AuthBloc(
      repository: repository,
      sessionExpired: const Stream.empty(),
    )..add(const AuthSessionRestoreRequested());
    addTearDown(auth.close);

    await tester.pumpWidget(
      ParkSpotApp(
        config: AppConfig(
          flavor: Flavor.dev,
          apiBaseUrl: Uri.parse('http://localhost:3000/v1'),
        ),
        authBloc: auth,
        onboarding: InMemoryOnboardingStatus(),
      ),
    );
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Find a spot before you leave'), findsOneWidget);
  });
}
