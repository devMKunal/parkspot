import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/features/permission/presentation/permission_page.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockLocationService location;
  bool? result;

  setUp(() {
    location = MockLocationService();
    result = null;
  });

  /// The map pushes the rationale and waits for a bool.
  Future<void> pumpFromMap(WidgetTester tester, {bool dark = false}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () async =>
                result = await context.push<bool>('/permission'),
            child: const Text('map'),
          ),
        ),
        GoRoute(
          path: '/permission',
          builder: (_, _) => PermissionPage(location: location),
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
    await tester.tap(find.text('map'));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('renders the design copy (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pumpFromMap(tester, dark: dark);

      expect(find.text('Can we see where you are?'), findsOneWidget);
      expect(find.text('412 m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Allow asks the OS and reports the answer', (tester) async {
    when(() => location.request()).thenAnswer((_) async => true);
    await pumpFromMap(tester);

    await tester.tap(find.text('Allow location'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    verify(() => location.request()).called(1);
  });

  testWidgets("Not now doesn't ask again", (tester) async {
    when(() => location.skip()).thenAnswer((_) async {});
    await pumpFromMap(tester);

    await tester.tap(find.text("Not now, I'll search"));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verify(() => location.skip()).called(1);
    verifyNever(() => location.request());
  });
}
