import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';
import 'package:parkspot/router/auth_status.dart';

/// Stand-in for AuthBloc and the onboarding flag until they exist, so the
/// router and screens can be exercised end to end.
///
/// It fakes the cold-start check: [status] starts `unknown` and settles to
/// `restoresTo` after `restoreDelay`, like a refresh-token lookup would.
// TODO(dev): delete once AuthBloc lands; see lib/router/README.md.
class DevSession {
  DevSession({
    Duration restoreDelay = const Duration(milliseconds: 1200),
    AuthStatus restoresTo = AuthStatus.unauthenticated,
    bool onboardingSeen = false,
  }) : onboarding = InMemoryOnboardingStatus(seen: onboardingSeen) {
    _restore = Timer(restoreDelay, () => status.value = restoresTo);
  }

  final ValueNotifier<AuthStatus> status = ValueNotifier(AuthStatus.unknown);
  final InMemoryOnboardingStatus onboarding;
  late final Timer _restore;

  void signIn() => _settle(AuthStatus.authenticated);
  void signOut() => _settle(AuthStatus.unauthenticated);

  /// An explicit sign-in or out beats the pending fake restore.
  void _settle(AuthStatus next) {
    _restore.cancel();
    status.value = next;
  }

  void dispose() {
    _restore.cancel();
    status.dispose();
    onboarding.dispose();
  }
}

/// [OnboardingStatus] that forgets on restart.
// TODO(dev): replace with one backed by shared_preferences.
class InMemoryOnboardingStatus implements OnboardingStatus {
  InMemoryOnboardingStatus({bool seen = false}) : _seen = ValueNotifier(seen);

  final ValueNotifier<bool> _seen;

  @override
  ValueListenable<bool> get seen => _seen;

  @override
  Future<void> markSeen() async => _seen.value = true;

  void dispose() => _seen.dispose();
}

/// Puts the [DevSession] where placeholder screens can reach it.
class DevSessionScope extends InheritedWidget {
  const DevSessionScope({
    required this.session,
    required super.child,
    super.key,
  });

  final DevSession session;

  static DevSession? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DevSessionScope>()?.session;

  @override
  bool updateShouldNotify(DevSessionScope oldWidget) =>
      session != oldWidget.session;
}
