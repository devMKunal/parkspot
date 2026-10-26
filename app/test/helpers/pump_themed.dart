import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/theme/app_theme.dart';

extension PumpThemed on WidgetTester {
  /// Pumps [child] inside a [MaterialApp] using the real ParkSpot theme.
  Future<void> pumpThemed(Widget child, {bool dark = false}) {
    return pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  /// A 390×844 phone, the design's frame, instead of the 800×600 default.
  void usePhoneSize() {
    view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
  }
}
