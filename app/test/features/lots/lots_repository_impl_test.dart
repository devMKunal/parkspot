import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/features/lots/data/lots_repository_impl.dart';

import '../../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  late LotsRepositoryImpl repository;

  setUp(() {
    api = FakeApi();
    repository = LotsRepositoryImpl(Dio()..httpClientAdapter = api);
  });

  const lotJson = {
    'id': 'fc',
    'name': 'FC Road Multilevel Parking',
    'address': 'Fergusson College Rd, Shivajinagar',
    'location': {'lat': 18.5246, 'lng': 73.8411},
    'pricePerHour': {'amount': 4000, 'currency': 'INR'},
    'totalSlots': 120,
    'freeSlots': 37,
    'photos': <String>[],
    'distanceMeters': 412,
  };

  test('nearby sends the centre and a capped radius', () async {
    api.on(
      'GET',
      '/lots/nearby',
      (_) => json(200, {
        'lots': [lotJson],
      }),
    );

    final lots = await repository.nearby(
      const GeoPoint(18.52, 73.85),
      radiusMeters: 50000,
    );

    expect(api.requests.single.queryParameters, {
      'lat': 18.52,
      'lng': 73.85,
      'radius': 10000,
      'limit': 50,
    });
    final lot = lots.single;
    expect(lot.name, 'FC Road Multilevel Parking');
    expect(lot.pricePerHour, const Money(4000));
    expect(lot.location, const GeoPoint(18.5246, 73.8411));
    expect((lot.freeSlots, lot.totalSlots), (37, 120));
  });

  test('byId: 404 is NOT_FOUND', () async {
    api.on('GET', '/lots/gone', (_) => apiError(404, 'NOT_FOUND'));

    await expectLater(
      repository.byId('gone'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.notFound,
        ),
      ),
    );
  });
}
