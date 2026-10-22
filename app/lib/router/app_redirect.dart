import 'package:parkspot/router/app_routes.dart';
import 'package:parkspot/router/auth_status.dart';

/// The routing rules, as a pure function so they can be tested as a table.
///
/// Returns where to send the user, or null to let them through.
///
/// * Unknown session: hold on the splash, remembering the deep link.
/// * Signed out on a private page: onboarding on first launch, else login.
/// * Signed in on splash or an auth page: back to the deep link, else map.
String? appRedirect({
  required Uri uri,
  required AuthStatus auth,
  required bool onboardingSeen,
}) {
  final path = uri.path;
  final from = _safeFrom(uri.queryParameters[AppRoutes.fromParam]);

  switch (auth) {
    case AuthStatus.unknown:
      if (path == AppRoutes.splash || path.startsWith('/dev/')) return null;
      return AppRoutes.withFrom(AppRoutes.splash, _deepLink(uri));

    case AuthStatus.unauthenticated:
      if (AppRoutes.isPublic(path) && path != AppRoutes.splash) return null;
      final target = onboardingSeen ? AppRoutes.login : AppRoutes.onboarding;
      final returnTo = path == AppRoutes.splash ? from : _deepLink(uri);
      return AppRoutes.withFrom(target, returnTo);

    case AuthStatus.authenticated:
      if (!AppRoutes.isEntry(path)) return null;
      return from ?? AppRoutes.home;
  }
}

/// The location worth coming back to, or null for the map (the default).
String? _deepLink(Uri uri) {
  if (uri.path == AppRoutes.home || AppRoutes.isEntry(uri.path)) return null;
  return _safeFrom(uri.toString());
}

/// Only in-app private paths: no `//host` and no auth pages, so a crafted
/// link can't send the user off-app or into a redirect loop.
String? _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null || AppRoutes.isEntry(path)) return null;
  return from;
}
