import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';
import 'package:parkspot/router/app_router.dart';
import 'package:parkspot/router/auth_status.dart';

class ParkSpotApp extends StatefulWidget {
  const ParkSpotApp({
    required this.config,
    required this.authBloc,
    required this.onboarding,
    this.themeMode,
    super.key,
  });

  final AppConfig config;
  final AuthBloc authBloc;
  final OnboardingStatus onboarding;

  /// Profile › Appearance; follows the system when null.
  final ValueListenable<ThemeMode>? themeMode;

  @override
  State<ParkSpotApp> createState() => _ParkSpotAppState();
}

class _ParkSpotAppState extends State<ParkSpotApp> {
  late final StreamValueNotifier<AuthStatus> _authStatus = StreamValueNotifier(
    widget.authBloc.stream.map((state) => state.status),
    initial: widget.authBloc.state.status,
  );

  late final ValueListenable<ThemeMode> _themeMode =
      widget.themeMode ?? ValueNotifier(ThemeMode.system);

  late final GoRouter _router = createAppRouter(
    authStatus: _authStatus,
    onboarding: widget.onboarding,
    includeDevRoutes: widget.config.isDev,
  );

  @override
  void dispose() {
    _router.dispose();
    _authStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authBloc,
      child: ValueListenableBuilder(
        valueListenable: _themeMode,
        builder: (context, mode, _) => MaterialApp.router(
          title: 'ParkSpot',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
