import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/app.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/features/splash/presentation/splash_page.dart';

void main() {
  testWidgets('boots to the splash, then onboarding on first launch', (
    tester,
  ) async {
    await tester.pumpWidget(
      ParkSpotApp(
        config: AppConfig(
          flavor: Flavor.dev,
          apiBaseUrl: Uri.parse('http://localhost:3000/v1'),
        ),
      ),
    );
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Find a spot before you leave'), findsOneWidget);
  });
}
