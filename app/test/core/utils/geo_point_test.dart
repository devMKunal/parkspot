import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/utils/geo_point.dart';

void main() {
  test('distance in metres', () {
    const fcRoad = GeoPoint(18.5246, 73.8411);
    const koregaonPark = GeoPoint(18.5362, 73.8940);

    expect(fcRoad.distanceTo(fcRoad), 0);
    // About 5.7 km across the city, either way round.
    expect(fcRoad.distanceTo(koregaonPark), inInclusiveRange(5600, 5800));
    expect(koregaonPark.distanceTo(fcRoad), fcRoad.distanceTo(koregaonPark));
  });
}
