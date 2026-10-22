import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/dev/dev_session.dart';
import 'package:parkspot/router/app_router.dart';

class ParkSpotApp extends StatefulWidget {
  const ParkSpotApp({required this.config, super.key});

  final AppConfig config;

  @override
  State<ParkSpotApp> createState() => _ParkSpotAppState();
}

class _ParkSpotAppState extends State<ParkSpotApp> {
  // TODO(dev): swap DevSession for AuthBloc; see lib/router/README.md.
  final _session = DevSession();

  late final GoRouter _router = createAppRouter(
    authStatus: _session.status,
    onboarding: _session.onboarding,
    includeDevRoutes: widget.config.isDev,
  );

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DevSessionScope(
      session: _session,
      child: MaterialApp.router(
        title: 'ParkSpot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: _router,
      ),
    );
  }
}
