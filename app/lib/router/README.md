# Routing

`go_router`, configured in `app_router.dart`. Screens navigate with the
paths in `app_routes.dart` (`context.go(AppRoutes.book(lotId))`), never with
string literals.

## Who decides where the user goes

The redirect in `app_redirect.dart` is the only place that moves the user
between the splash, auth pages and the app. It is a pure function of three
things, so it is tested as a table in `test/router/app_redirect_test.dart`:

| Auth status | Where the user is | Goes to |
| --- | --- | --- |
| `unknown` | anywhere | `/splash` (keeps a deep link in `?from=`) |
| `unauthenticated` | splash or a private page | `/onboarding` on first launch, else `/login` |
| `authenticated` | splash, onboarding, sign-up, login | `?from=` if set, else `/` |

Screens never navigate after sign-in, sign-out or session restore. They
change state, and the redirect re-runs because the router listens to it
(`refreshListenable`).

## Plugging in AuthBloc

The router only needs a `ValueListenable<AuthStatus>` and an
`OnboardingStatus` (`lib/features/onboarding/domain/onboarding_status.dart`).
Today both come from `DevSession` (`lib/dev/dev_session.dart`), a stub that
fakes the refresh-token check and keeps "onboarding seen" in memory. When
AuthBloc exists:

1. On start, AuthBloc reads the refresh token from secure storage
   (`StorageKeys.refreshToken`). None: emit `unauthenticated`. Found: call
   `POST /auth/refresh`, then `GET /me`, and emit `authenticated`; on 401,
   wipe the token and emit `unauthenticated`. Network errors need a
   decision (retry screen, or let an offline user in with the cached user).
2. In `app.dart`, create the router from the bloc:

   ```dart
   final authStatus = StreamValueNotifier(
     authBloc.stream.map((state) => state.status),
     initial: authBloc.state.status,
   );
   final router = createAppRouter(
     authStatus: authStatus,
     onboarding: onboardingStatus, // your shared_preferences-backed one
     includeDevRoutes: config.isDev,
   );
   ```

   Create both once (in a `State` or your DI graph), never in `build`, and
   dispose them with the app.
3. Implement `OnboardingStatus` over shared_preferences
   (`StorageKeys.onboardingSeen`), loaded before the router starts so the
   splash knows where to go. The onboarding page already calls `markSeen`.
4. Delete `DevSession`, `DevSessionScope`, `InMemoryOnboardingStatus` and
   the stub actions on `RoutePlaceholderPage`.

## Placeholders

Each route without a real screen shows `RoutePlaceholderPage`, with buttons
for the next steps in the flow. Swap them for real pages as they are built.
