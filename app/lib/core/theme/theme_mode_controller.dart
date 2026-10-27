import 'package:flutter/material.dart';
import 'package:parkspot/core/constants/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// System, light or dark, remembered across launches. The app listens to
/// it; Profile › Appearance sets it.
class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController(this._prefs)
    : super(
        ThemeMode.values.asNameMap()[_prefs.getString(StorageKeys.themeMode)] ??
            ThemeMode.system,
      );

  final SharedPreferencesWithCache _prefs;

  Future<void> select(ThemeMode mode) async {
    value = mode;
    try {
      await _prefs.setString(StorageKeys.themeMode, mode.name);
    } on Object catch (e) {
      // The choice still applies for this session.
      debugPrint('Could not save theme mode: $e');
    }
  }
}
