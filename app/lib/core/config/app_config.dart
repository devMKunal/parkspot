import 'package:flutter/foundation.dart';

enum Flavor { dev, prod }

/// Build-time configuration, read once from `--dart-define-from-file`.
///
/// Run with `flutter run --dart-define-from-file=env/dev.json`. Only `main`
/// calls [AppConfig.fromEnvironment]; everything else receives the instance,
/// so tests can build an [AppConfig] directly.
@immutable
final class AppConfig {
  const AppConfig({required this.flavor, required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    // 10.0.2.2 is the host machine as seen from the Android emulator.
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000/v1',
    );
    return AppConfig(
      flavor: Flavor.values.byName(flavor),
      apiBaseUrl: Uri.parse(url),
    );
  }

  final Flavor flavor;

  /// Includes the version prefix, e.g. `http://10.0.2.2:3000/v1`.
  final Uri apiBaseUrl;

  bool get isDev => flavor == Flavor.dev;
}
