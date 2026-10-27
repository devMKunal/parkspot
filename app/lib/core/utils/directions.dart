import 'package:flutter/material.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens driving directions to [to] in Google Maps (app or web).
// ponytail: hands off to Google Maps; an in-app polyline needs the paid
// Directions API, add it with the geofence work.
Future<void> openDirections(BuildContext context, GeoPoint to) async {
  final messenger = ScaffoldMessenger.of(context);
  final url = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${to.lat},${to.lng}',
    'travelmode': 'driving',
  });
  final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't open directions.")),
    );
  }
}
