import 'package:flutter/material.dart';
import 'package:parkspot/app.dart';
import 'package:parkspot/core/config/app_config.dart';

void main() {
  runApp(ParkSpotApp(config: AppConfig.fromEnvironment()));
}
