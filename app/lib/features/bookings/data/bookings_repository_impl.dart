import 'package:dio/dio.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/bookings_repository.dart';

/// docs/bookings-api.md, docs/payments-api.md
class BookingsRepositoryImpl implements BookingsRepository {
  BookingsRepositoryImpl(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _post(String path, [Object? body]) async =>
      (await guardApi(
        () => _dio.post<Map<String, dynamic>>(path, data: body),
      )).data!;

  static Booking _booking(Map<String, dynamic> data) =>
      Booking.fromJson(data['booking'] as Map<String, dynamic>);

  @override
  Future<(Booking, PaymentOrder)> create({
    required String lotId,
    required DateTime start,
    required Duration duration,
  }) async {
    final data = await _post('/bookings', {
      'lotId': lotId,
      'start': start.toUtc().toIso8601String(),
      'durationMinutes': duration.inMinutes,
    });
    return (
      _booking(data),
      PaymentOrder.fromJson(data['payment'] as Map<String, dynamic>),
    );
  }

  @override
  Future<Booking> get(String id) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/bookings/$id'),
    );
    return _booking(res.data!);
  }

  @override
  Future<Booking> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async => _booking(
    await _post('/payments/verify', {
      'orderId': orderId,
      'paymentId': paymentId,
      'signature': signature,
    }),
  );

  @override
  Future<Booking> checkIn(String id, {required String passCode}) async =>
      _booking(await _post('/bookings/$id/checkin', {'passCode': passCode}));

  @override
  Future<PaymentOrder> extend(String id, {required Duration by}) async {
    final data = await _post('/bookings/$id/extend', {'minutes': by.inMinutes});
    return PaymentOrder.fromJson(data['payment'] as Map<String, dynamic>);
  }

  @override
  Future<Booking> end(String id) async =>
      _booking(await _post('/bookings/$id/end'));

  @override
  Future<List<Booking>> mine({Set<BookingStatus>? statuses}) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>(
        '/me/bookings',
        queryParameters: {
          if (statuses != null)
            'status': statuses.map((s) => s.name.toUpperCase()).join(','),
        },
      ),
    );
    return [
      for (final json in res.data!['bookings'] as List<dynamic>)
        Booking.fromJson(json as Map<String, dynamic>),
    ];
  }
}
