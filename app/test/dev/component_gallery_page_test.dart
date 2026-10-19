import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/dev/component_gallery_page.dart';

void main() {
  // Renders every shared widget on a phone-sized screen in both themes; any
  // overflow or missing theme extension fails the test.
  for (final dark in [false, true]) {
    testWidgets('gallery renders in ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const ComponentGalleryPage(),
        ),
      );

      final list = find.byType(Scrollable).first;
      await tester.dragUntilVisible(
        find.text('Countdown and onboarding'),
        list,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
