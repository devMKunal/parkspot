/// UI-side values mirrored from the API docs.
///
/// The server stays the authority on every rule here: these exist so pickers
/// and validation can render before a request. Each group names the doc it
/// mirrors so a contract change is easy to chase.
abstract final class AppConstants {
  // api/src/modules/auth/auth.schemas.ts
  static const nameMaxLength = 80;
  static const passwordMinLength = 8;
  static const passwordMaxLength = 128;

  // docs/lots-api.md
  static const nearbyRadiusMeters = 2000; // server default, max 10000
  static const nearbyLimit = 50;
  static const mapIdleDebounce = Duration(milliseconds: 400);

  // docs/bookings-api.md
  static const slotStep = Duration(minutes: 15);
  static const minBooking = Duration(minutes: 30);
  static const maxBooking = Duration(minutes: 720);
  static const maxBookAhead = Duration(days: 7);

  // UI only: free / total ratios that pick the availability colour.
  static const availabilityMediumRatio = 0.30;
  static const availabilityLowRatio = 0.10;

  static const defaultMapZoom = 15.0;

  /// Map centre when location permission is denied (Pune city centre).
  static const ({double lat, double lng}) puneFallback = (
    lat: 18.5204,
    lng: 73.8567,
  );

  // Networking, for the dio client.
  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);
}
