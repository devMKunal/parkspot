/// Keys for on-device storage. One place, so a rename can't orphan data.
abstract final class StorageKeys {
  /// flutter_secure_storage (Keystore / Keychain). The access token stays in
  /// memory only.
  static const refreshToken = 'auth.refresh_token';

  // shared_preferences
  static const onboardingSeen = 'app.onboarding_seen';

  /// The location rationale shows once, before the first OS prompt.
  static const locationRationaleSeen = 'app.location_rationale_seen';
  static const themeMode = 'app.theme_mode';
}
