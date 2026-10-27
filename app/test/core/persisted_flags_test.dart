import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/constants/storage_keys.dart';
import 'package:parkspot/core/theme/theme_mode_controller.dart';
import 'package:parkspot/features/onboarding/data/prefs_onboarding_status.dart';

import '../helpers/prefs.dart';

void main() {
  test('onboarding "seen" survives a relaunch', () async {
    final first = PrefsOnboardingStatus(await testPrefs());
    expect(first.seen.value, isFalse);
    await first.markSeen();
    expect(first.seen.value, isTrue);

    final relaunched = PrefsOnboardingStatus(
      await testPrefs({StorageKeys.onboardingSeen: true}),
    );
    expect(relaunched.seen.value, isTrue);
  });

  test('theme mode defaults to system and remembers a choice', () async {
    final prefs = await testPrefs();
    final controller = ThemeModeController(prefs);
    expect(controller.value, ThemeMode.system);

    await controller.select(ThemeMode.dark);
    expect(controller.value, ThemeMode.dark);
    expect(prefs.getString(StorageKeys.themeMode), 'dark');

    final relaunched = ThemeModeController(
      await testPrefs({StorageKeys.themeMode: 'light'}),
    );
    expect(relaunched.value, ThemeMode.light);
  });

  test('an unknown stored theme falls back to system', () async {
    final controller = ThemeModeController(
      await testPrefs({StorageKeys.themeMode: 'sepia'}),
    );
    expect(controller.value, ThemeMode.system);
  });
}
