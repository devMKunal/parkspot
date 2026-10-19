import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts before every test file, so widget tests measure
/// real glyphs instead of the square test font (which overstates widths).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    _load('BricolageGrotesque', ['SemiBold', 'Bold', 'ExtraBold']),
    _load('PlusJakartaSans', ['Regular', 'Medium', 'SemiBold', 'Bold']),
  ]);
  await testMain();
}

Future<void> _load(String family, List<String> styles) {
  final loader = FontLoader(family);
  for (final style in styles) {
    loader.addFont(rootBundle.load('assets/fonts/$family-$style.ttf'));
  }
  return loader.load();
}
