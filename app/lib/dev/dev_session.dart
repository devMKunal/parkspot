import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:parkspot/router/auth_status.dart';

/// Stand-in for AuthBloc and the onboarding flag until they exist, so the
/// router and splash can be exercised end to end.
///
/// It fakes the cold-start check: [status] starts `unknown` and settles to
/// `restoresTo` after `restoreDelay`, like a refresh-token lookup would.
// TODO(dev): delete once AuthBloc lands; see lib/router/README.md.
class DevSession {
  DevSession({
    Duration restoreDelay = const Duration(milliseconds: 1200),
    AuthStatus restoresTo = AuthStatus.unauthenticated,
    bool onboardingSeen = false,
  }) : onboardingSeen = ValueNotifier(onboardingSeen) {
    _restore = Timer(restoreDelay, () => status.value = restoresTo);
  }

  final ValueNotifier<AuthStatus> status = ValueNotifier(AuthStatus.unknown);
  final ValueNotifier<bool> onboardingSeen;
  late final Timer _restore;

  void signIn() => _settle(AuthStatus.authenticated);
  void signOut() => _settle(AuthStatus.unauthenticated);

  /// An explicit sign-in or out beats the pending fake restore.
  void _settle(AuthStatus next) {
    _restore.cancel();
    status.value = next;
  }

  void completeOnboarding() => onboardingSeen.value = true;

  void dispose() {
    _restore.cancel();
    status.dispose();
    onboardingSeen.dispose();
  }
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
