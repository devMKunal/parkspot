import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/config/app_config.dart';

void main() {
  String url(DeviceKind device, {String lanHost = ''}) =>
      AppConfig.devApiBaseUrl(
        device: device,
        port: 3000,
        lanHost: lanHost,
      ).toString();

  test('each device reaches the Mac its own way', () {
    expect(url(DeviceKind.androidEmulator), 'http://10.0.2.2:3000/v1');
    expect(url(DeviceKind.iosSimulator), 'http://localhost:3000/v1');
    expect(
      url(DeviceKind.physical, lanHost: '192.168.1.42'),
      'http://192.168.1.42:3000/v1',
    );
  });

  test('a physical phone without LAN_HOST fails loudly', () {
    expect(() => url(DeviceKind.physical), throwsStateError);
  });
}
