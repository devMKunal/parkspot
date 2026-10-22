/// Every path in the app. Screens navigate with these, never with literals.
abstract final class AppRoutes {
  // Entry and auth: reachable signed out.
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const signup = '/signup';
  static const login = '/login';

  // Signed in.
  static const home = '/';
  static const permission = '/permission';
  static const trips = '/trips';
  static const profile = '/profile';

  static String book(String lotId) => '/lots/$lotId/book';
  static String bookingPaid(String bookingId) => '/bookings/$bookingId/paid';
  static String bookingFailed(String bookingId) =>
      '/bookings/$bookingId/failed';

  /// The active pass (QR, countdown, extend, end).
  static String booking(String bookingId) => '/bookings/$bookingId';

  /// Dev builds only: the component gallery.
  static const gallery = '/dev/gallery';

  /// Query parameter that carries a deep link through splash and login, so
  /// the user lands where they were going once signed in.
  static const fromParam = 'from';

  static const Set<String> _signedOut = {splash, onboarding, signup, login};

  /// Paths a signed-out user may see. Dev tools are open too.
  static bool isPublic(String path) =>
      _signedOut.contains(path) || path.startsWith('/dev/');

  /// Splash, onboarding, sign-up and login: a signed-in user is sent on.
  static bool isEntry(String path) => _signedOut.contains(path);

  /// [path] with `?from=` when there is somewhere to return to.
  static String withFrom(String path, String? from) => from == null
      ? path
      : Uri(path: path, queryParameters: {fromParam: from}).toString();
}
