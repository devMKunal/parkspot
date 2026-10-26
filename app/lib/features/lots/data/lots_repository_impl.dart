import 'package:dio/dio.dart';
import 'package:parkspot/core/constants/app_constants.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/lots/domain/lots_repository.dart';

class LotsRepositoryImpl implements LotsRepository {
  LotsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Lot>> nearby(GeoPoint center, {required int radiusMeters}) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>(
        '/lots/nearby',
        queryParameters: {
          'lat': center.lat,
          'lng': center.lng,
          'radius': radiusMeters.clamp(1, AppConstants.maxNearbyRadiusMeters),
          'limit': AppConstants.nearbyLimit,
        },
      ),
    );
    return [
      for (final json in res.data!['lots'] as List<dynamic>)
        Lot.fromJson(json as Map<String, dynamic>),
    ];
  }

  @override
  Future<Lot> byId(String id) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/lots/$id'),
    );
    return Lot.fromJson(res.data!['lot'] as Map<String, dynamic>);
  }
}
