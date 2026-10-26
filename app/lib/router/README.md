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

## Where the auth status comes from

`AuthBloc` (`lib/features/auth/presentation/bloc/auth_bloc.dart`). `app.dart`
adapts its stream with `StreamValueNotifier` and hands it to
`createAppRouter`, together with the shared_preferences-backed
`PrefsOnboardingStatus`; both are built once in `lib/core/di/injector.dart`.

On start AuthBloc restores the session (`POST /auth/refresh`, then `GET /me`).
Offline, it stays `unknown` with a `restoreError`, and the splash offers a
retry instead of logging the user out. Mid-session, the auth interceptor
reports a dead refresh token and AuthBloc emits `unauthenticated`.

Sign-up and login pass the new user to AuthBloc (`AuthLoggedIn`); the
redirect does the rest. Their "Log in" / "Create an account" links keep
`?from=` so a deep link survives hopping between the two.

## Placeholders

Each route without a real screen shows `RoutePlaceholderPage`, with buttons
for the next steps in the flow. Swap them for real pages as they are built.
