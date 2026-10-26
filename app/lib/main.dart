import 'package:flutter/material.dart';
import 'package:parkspot/app.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/core/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  await configureDependencies(config);
  runApp(ParkSpotApp(config: config, authBloc: getIt(), onboarding: getIt()));
}
