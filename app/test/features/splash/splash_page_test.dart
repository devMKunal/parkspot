import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/features/splash/presentation/splash_page.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('renders in ${dark ? 'dark' : 'light'} theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const SplashPage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ParkSpot'), findsOneWidget);
      expect(find.text('Parking, sorted.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('is announced as loading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const SplashPage()),
    );

    expect(find.bySemanticsLabel('ParkSpot is loading'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('holds the dots still when animations are off', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(theme: AppTheme.light(), home: const SplashPage()),
      ),
    );

    // Settles only if nothing is animating.
    await tester.pumpAndSettle();
  });
}
