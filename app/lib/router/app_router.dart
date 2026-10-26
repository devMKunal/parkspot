import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/dev/component_gallery_page.dart';
import 'package:parkspot/dev/route_placeholder_page.dart';
import 'package:parkspot/features/active_booking/presentation/screen/active_booking_page.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/booking/presentation/screen/booking_page.dart';
import 'package:parkspot/features/login/presentation/screen/login_page.dart';
import 'package:parkspot/features/map/presentation/screen/map_page.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';
import 'package:parkspot/features/onboarding/presentation/onboarding_page.dart';
import 'package:parkspot/features/payment_result/presentation/screen/payment_failed_page.dart';
import 'package:parkspot/features/payment_result/presentation/screen/payment_success_page.dart';
import 'package:parkspot/features/permission/presentation/permission_page.dart';
import 'package:parkspot/features/signup/presentation/screen/signup_page.dart';
import 'package:parkspot/features/splash/presentation/splash_page.dart';
import 'package:parkspot/router/app_redirect.dart';
import 'package:parkspot/router/app_routes.dart';
import 'package:parkspot/router/auth_status.dart';

/// Builds the app's router. Create it once (in a State or the DI graph),
/// never inside a build method, or navigation state resets on rebuild.
///
/// The router only listens: [authStatus] and [onboarding] change elsewhere
/// (AuthBloc, the onboarding screen) and the redirect re-runs.
GoRouter createAppRouter({
  required ValueListenable<AuthStatus> authStatus,
  required OnboardingStatus onboarding,
  bool includeDevRoutes = false,
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge([authStatus, onboarding.seen]),
    redirect: (context, state) => appRedirect(
      uri: state.uri,
      auth: authStatus.value,
      onboardingSeen: onboarding.seen.value,
    ),
    errorBuilder: (context, state) => const RoutePlaceholderPage(
      title: 'Nothing here',
      note: "This page doesn't exist.",
      actions: [PlaceholderAction.go('Back to the map', AppRoutes.home)],
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) => SplashPage(
            error: auth.restoreError,
            onRetry: () => context.read<AuthBloc>().add(
              const AuthSessionRestoreRequested(),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) =>
            OnboardingPage(onFinished: () => unawaited(onboarding.markSeen())),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => SignupPage(
          onLogIn: () => context.go(_keepFrom(AppRoutes.login, state)),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginPage(
          onSignUp: () => context.go(_keepFrom(AppRoutes.signup, state)),
        ),
      ),
      // TODO(dev): replace each RoutePlaceholderPage with the real screen.
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MapPage(),
        // Nested under the map, so a deep link still has a back button.
        routes: [
          GoRoute(
            path: 'permission',
            builder: (context, state) => const PermissionPage(),
          ),
          GoRoute(
            path: 'lots/:lotId/book',
            builder: (context, state) =>
                BookingPage(lotId: state.pathParameters['lotId']!),
          ),
          // Before the pass: '/bookings/:id' would otherwise claim these.
          GoRoute(
            path: 'bookings/:bookingId/paid',
            builder: (context, state) => PaymentSuccessPage(
              bookingId: state.pathParameters['bookingId']!,
            ),
          ),
          GoRoute(
            path: 'bookings/:bookingId/failed',
            builder: (context, state) => PaymentFailedPage(
              bookingId: state.pathParameters['bookingId']!,
            ),
          ),
          GoRoute(
            path: 'bookings/:bookingId',
            builder: (context, state) => ActiveBookingPage(
              bookingId: state.pathParameters['bookingId']!,
            ),
          ),
          GoRoute(
            path: 'trips',
            builder: (context, state) =>
                const RoutePlaceholderPage(title: 'My trips'),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const RoutePlaceholderPage(
              title: 'Profile',
              actions: [PlaceholderAction.run('Log out', _logOut)],
            ),
          ),
        ],
      ),
      if (includeDevRoutes)
        GoRoute(
          path: AppRoutes.gallery,
          builder: (context, state) => const ComponentGalleryPage(),
        ),
    ],
  );
}

/// [path] carrying the current page's `?from=`, so a deep link survives
/// hopping between sign-up and login.
String _keepFrom(String path, GoRouterState state) =>
    AppRoutes.withFrom(path, state.uri.queryParameters[AppRoutes.fromParam]);

void _logOut(BuildContext context) =>
    context.read<AuthBloc>().add(const AuthLogoutRequested());
