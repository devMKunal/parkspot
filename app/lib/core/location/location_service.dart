import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:parkspot/core/constants/storage_keys.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground location only, plus the "rationale shown once" flag.
class LocationService {
  LocationService(this._prefs);

  final SharedPreferencesWithCache _prefs;

  /// True on the first visit to the map, before the OS has ever asked.
  Future<bool> shouldExplain() async {
    if (_prefs.getBool(StorageKeys.locationRationaleSeen) ?? false) {
      return false;
    }
    return await Geolocator.checkPermission() == LocationPermission.denied;
  }

  /// Shows the OS prompt (if it still can). True when access was granted.
  Future<bool> request() async {
    await _markExplained();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _granted(permission);
  }

  /// "Not now, I'll search": don't explain again.
  Future<void> skip() => _markExplained();

  /// Where the user is, or null without permission, with location off, or
  /// when no fix comes in time. Never throws.
  Future<GeoPoint?> current() async {
    try {
      if (!_granted(await Geolocator.checkPermission())) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on Object catch (e) {
      debugPrint('No location fix: $e');
      try {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : GeoPoint(last.latitude, last.longitude);
      } on Object {
        return null;
      }
    }
  }

  /// Location access was refused for good; only Settings can change it.
  Future<bool> isBlocked() async =>
      await Geolocator.checkPermission() == LocationPermission.deniedForever;

  Future<bool> openSettings() => Geolocator.openAppSettings();

  Future<void> _markExplained() async {
    try {
      await _prefs.setBool(StorageKeys.locationRationaleSeen, true);
    } on Object catch (e) {
      debugPrint('Could not save rationale flag: $e');
    }
  }

  static bool _granted(LocationPermission p) =>
      p == LocationPermission.whileInUse || p == LocationPermission.always;
}
