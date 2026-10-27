import 'package:flutter/foundation.dart';
import 'package:parkspot/core/constants/storage_keys.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [OnboardingStatus] kept in shared_preferences. The cache is loaded before
/// the router starts, so [seen] is right on the first frame.
class PrefsOnboardingStatus implements OnboardingStatus {
  PrefsOnboardingStatus(this._prefs)
    : _seen = ValueNotifier(
        _prefs.getBool(StorageKeys.onboardingSeen) ?? false,
      );

  final SharedPreferencesWithCache _prefs;
  final ValueNotifier<bool> _seen;

  @override
  ValueListenable<bool> get seen => _seen;

  @override
  Future<void> markSeen() async {
    _seen.value = true;
    try {
      await _prefs.setBool(StorageKeys.onboardingSeen, true);
    } on Object catch (e) {
      // Not worth failing for: onboarding just shows again next launch.
      debugPrint('Could not save onboarding flag: $e');
    }
  }
}
