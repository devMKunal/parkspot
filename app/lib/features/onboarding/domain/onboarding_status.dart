import 'package:flutter/foundation.dart';

/// Whether this device has been through onboarding.
///
/// The router reads [seen] to pick onboarding or login for a signed-out
/// user; the onboarding page calls [markSeen] when the user leaves it.
/// The real implementation persists the flag (shared_preferences under
/// `StorageKeys.onboardingSeen`) and loads it before the router starts.
abstract interface class OnboardingStatus {
  ValueListenable<bool> get seen;

  /// Must not throw: if saving fails, onboarding simply shows again.
  Future<void> markSeen();
}
