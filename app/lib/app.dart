import 'package:flutter/material.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/dev/component_gallery_page.dart';

class ParkSpotApp extends StatelessWidget {
  const ParkSpotApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkSpot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // TODO(dev): swap for go_router and the splash route once auth lands.
      home: const ComponentGalleryPage(),
    );
  }
}
