import 'dart:math' as math;

import 'package:equatable/equatable.dart';

class GeoPoint extends Equatable {
  const GeoPoint(this.lat, this.lng);

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    (json['lat'] as num).toDouble(),
    (json['lng'] as num).toDouble(),
  );

  final double lat;
  final double lng;

  /// Great-circle distance in metres (haversine; plenty for city scale).
  int distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.lat - lat);
    final dLng = rad(other.lng - lng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(other.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return (2 * earthRadius * math.asin(math.sqrt(a))).round();
  }

  @override
  List<Object?> get props => [lat, lng];

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}
