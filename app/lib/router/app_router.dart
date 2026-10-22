import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/dev/component_gallery_page.dart';
import 'package:parkspot/dev/route_placeholder_page.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';
import 'package:parkspot/features/onboarding/presentation/onboarding_page.dart';
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
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) =>
            OnboardingPage(onFinished: () => unawaited(onboarding.markSeen())),
      ),
      // TODO(dev): replace each RoutePlaceholderPage with the real screen.
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const RoutePlaceholderPage(
          title: 'Sign up',
          actions: [
            PlaceholderAction.stub('Create account', StubAuthAction.signIn),
            PlaceholderAction.go('I already have an account', AppRoutes.login),
          ],
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const RoutePlaceholderPage(
          title: 'Log in',
          actions: [
            PlaceholderAction.stub('Log in', StubAuthAction.signIn),
            PlaceholderAction.go('New here? Sign up', AppRoutes.signup),
          ],
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => RoutePlaceholderPage(
          title: 'Map',
          actions: [
            PlaceholderAction.go('Book a spot', AppRoutes.book(_demoLot)),
            const PlaceholderAction.go(
              'Location permission',
              AppRoutes.permission,
            ),
            const PlaceholderAction.go('My trips', AppRoutes.trips),
            const PlaceholderAction.go('Profile', AppRoutes.profile),
            if (includeDevRoutes)
              const PlaceholderAction.go(
                'Component gallery',
                AppRoutes.gallery,
              ),
          ],
        ),
        // Nested under the map, so a deep link still has a back button.
        routes: [
          GoRoute(
            path: 'permission',
            builder: (context, state) => const RoutePlaceholderPage(
              title: 'Location permission',
              actions: [PlaceholderAction.go('Allow', AppRoutes.home)],
            ),
          ),
          GoRoute(
            path: 'lots/:lotId/book',
            builder: (context, state) => RoutePlaceholderPage(
              title: 'Book lot ${state.pathParameters['lotId']}',
              actions: [
                PlaceholderAction.go(
                  'Pay (succeeds)',
                  AppRoutes.bookingPaid(_demoBooking),
                ),
                PlaceholderAction.go(
                  'Pay (fails)',
                  AppRoutes.bookingFailed(_demoBooking),
                ),
              ],
            ),
          ),
          // Before the pass: '/bookings/:id' would otherwise claim these.
          GoRoute(
            path: 'bookings/:bookingId/paid',
            builder: (context, state) => RoutePlaceholderPage(
              title: 'Payment successful',
              actions: [
                PlaceholderAction.go(
                  'Show my pass',
                  AppRoutes.booking(state.pathParameters['bookingId']!),
                ),
              ],
            ),
          ),
          GoRoute(
            path: 'bookings/:bookingId/failed',
            builder: (context, state) => RoutePlaceholderPage(
              title: 'Payment failed',
              actions: [
                PlaceholderAction.go('Try again', AppRoutes.book(_demoLot)),
                const PlaceholderAction.go('Back to the map', AppRoutes.home),
              ],
            ),
          ),
          GoRoute(
            path: 'bookings/:bookingId',
            builder: (context, state) => RoutePlaceholderPage(
              title: 'Pass ${state.pathParameters['bookingId']}',
              actions: const [
                PlaceholderAction.go('Back to the map', AppRoutes.home),
              ],
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
              actions: [
                PlaceholderAction.stub('Log out', StubAuthAction.signOut),
              ],
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

const _demoLot = 'demo-lot';
const _demoBooking = 'demo-booking';
