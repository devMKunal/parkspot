import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

enum Flavor { dev, prod }

/// Where the app is running, as far as reaching the dev API goes.
enum DeviceKind { androidEmulator, iosSimulator, physical, other }

/// Build-time configuration, read once from `--dart-define-from-file`.
///
/// Run with `flutter run --dart-define-from-file=env/dev.json`. Only `main`
/// calls [AppConfig.load]; everything else receives the instance, so tests
/// can build an [AppConfig] directly.
@immutable
final class AppConfig {
  const AppConfig({required this.flavor, required this.apiBaseUrl});

  /// Reads the defines and, unless `API_BASE_URL` is set, picks the dev
  /// API host for the device it runs on (see [devApiBaseUrl]).
  static Future<AppConfig> load() async {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    const explicit = String.fromEnvironment('API_BASE_URL');
    const lanHost = String.fromEnvironment('LAN_HOST');
    const port = int.fromEnvironment('API_PORT', defaultValue: 3000);

    final url = explicit.isNotEmpty
        ? Uri.parse(explicit)
        : devApiBaseUrl(
            device: await _detectDevice(),
            port: port,
            lanHost: lanHost,
          );
    return AppConfig(flavor: Flavor.values.byName(flavor), apiBaseUrl: url);
  }

  /// The local API as seen from [device]:
  ///
  /// * Android emulator: `10.0.2.2`, the host Mac (its `localhost` is the
  ///   emulator itself).
  /// * iOS simulator: `localhost`, shared with the Mac.
  /// * Physical phone: the Mac's LAN IP, passed as `LAN_HOST`, on the same
  ///   Wi-Fi. Throws without it rather than silently calling the phone.
  static Uri devApiBaseUrl({
    required DeviceKind device,
    required int port,
    required String lanHost,
  }) {
    final host = switch (device) {
      DeviceKind.androidEmulator => '10.0.2.2',
      DeviceKind.iosSimulator || DeviceKind.other => 'localhost',
      DeviceKind.physical when lanHost.isNotEmpty => lanHost,
      DeviceKind.physical => throw StateError(
        "On a physical phone the API host is your Mac's LAN IP. Run with "
        r'--dart-define=LAN_HOST=$(ipconfig getifaddr en0)',
      ),
    };
    return Uri(scheme: 'http', host: host, port: port, path: '/v1');
  }

  static Future<DeviceKind> _detectDevice() async {
    if (kIsWeb) return DeviceKind.other;
    final info = DeviceInfoPlugin();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        (await info.androidInfo).isPhysicalDevice
            ? DeviceKind.physical
            : DeviceKind.androidEmulator,
      TargetPlatform.iOS =>
        (await info.iosInfo).isPhysicalDevice
            ? DeviceKind.physical
            : DeviceKind.iosSimulator,
      _ => DeviceKind.other,
    };
  }

  final Flavor flavor;

  /// Includes the version prefix, e.g. `http://10.0.2.2:3000/v1`.
  final Uri apiBaseUrl;

  bool get isDev => flavor == Flavor.dev;
}
