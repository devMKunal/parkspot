import 'dart:async';

import 'package:flutter/foundation.dart';

/// What the router needs to know about the session, and nothing more.
///
/// `unknown` is the cold-start state while the refresh token is being
/// checked; the router holds the user on the splash screen until it settles.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Adapts a stream into a [ValueListenable], so the router can listen to a
/// bloc without depending on it:
///
/// ```dart
/// StreamValueNotifier(
///   authBloc.stream.map((state) => state.status),
///   initial: authBloc.state.status,
/// )
/// ```
///
/// Listeners fire only when the value changes, so bloc states that keep the
/// same status don't re-run the redirect.
class StreamValueNotifier<T> extends ValueNotifier<T> {
  StreamValueNotifier(Stream<T> stream, {required T initial}) : super(initial) {
    _subscription = stream.listen((next) => value = next);
  }

  late final StreamSubscription<T> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
