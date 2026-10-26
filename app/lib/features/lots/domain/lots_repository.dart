import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/features/lots/domain/lot.dart';

/// Public lot discovery. Throws `ApiException`.
abstract interface class LotsRepository {
  /// Lots within [radiusMeters] of [center], nearest first.
  Future<List<Lot>> nearby(GeoPoint center, {required int radiusMeters});

  /// One lot with live availability.
  Future<Lot> byId(String id);
}
