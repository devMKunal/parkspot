import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/features/bookings/data/bookings_repository_impl.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';

import '../../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  late BookingsRepositoryImpl repository;

  setUp(() {
    api = FakeApi();
    repository = BookingsRepositoryImpl(Dio()..httpClientAdapter = api);
  });

  Map<String, dynamic> bookingJson([String status = 'PENDING']) => {
    'id': 'b1',
    'lotId': 'fc',
    'slotLabel': 'S014',
    'start': '2026-10-19T13:00:00.000Z',
    'end': '2026-10-19T15:00:00.000Z',
    'amount': {'amount': 8000, 'currency': 'INR'},
    'status': status,
    'lockExpiresAt': '2026-10-19T12:52:00.000Z',
    'passCode': status == 'CONFIRMED' ? 'PS-7Q2K' : null,
    'endedAt': null,
    'createdAt': '2026-10-19T12:42:00.000Z',
  };

  test('create sends a UTC start and minutes, returns the order', () async {
    api.on(
      'POST',
      '/bookings',
      (_) => json(201, {
        'booking': bookingJson(),
        'payment': {
          'provider': 'razorpay',
          'keyId': 'rzp_test_x',
          'orderId': 'order_1',
          'amount': 8000,
          'currency': 'INR',
        },
      }),
    );

    final (booking, order) = await repository.create(
      lotId: 'fc',
      start: DateTime.utc(2026, 10, 19, 13),
      duration: const Duration(hours: 2),
    );

    expect(api.requests.single.data, {
      'lotId': 'fc',
      'start': '2026-10-19T13:00:00.000Z',
      'durationMinutes': 120,
    });
    expect(booking.status, BookingStatus.pending);
    expect(booking.lockExpiresAt, DateTime.utc(2026, 10, 19, 12, 52));
    expect(booking.duration, const Duration(hours: 2));
    expect(order.orderId, 'order_1');
    expect(order.amount, const Money(8000));
  });

  test('verify forwards the signature and returns the booking', () async {
    api.on(
      'POST',
      '/payments/verify',
      (_) => json(200, {'booking': bookingJson('CONFIRMED')}),
    );

    final booking = await repository.verifyPayment(
      orderId: 'order_1',
      paymentId: 'pay_1',
      signature: 'sig',
    );

    expect(api.requests.single.data, {
      'orderId': 'order_1',
      'paymentId': 'pay_1',
      'signature': 'sig',
    });
    expect(booking.status, BookingStatus.confirmed);
    expect(booking.passCode, 'PS-7Q2K');
  });

  test('mine filters by status', () async {
    api.on(
      'GET',
      '/me/bookings',
      (_) => json(200, {
        'bookings': [bookingJson('CONFIRMED')],
      }),
    );

    final list = await repository.mine(
      statuses: {BookingStatus.confirmed, BookingStatus.active},
    );

    expect(api.requests.single.queryParameters, {'status': 'CONFIRMED,ACTIVE'});
    expect(list.single.id, 'b1');
  });

  test('check-in, extend and end hit their endpoints', () async {
    api
      ..on(
        'POST',
        '/bookings/b1/checkin',
        (_) => json(200, {'booking': bookingJson('ACTIVE')}),
      )
      ..on(
        'POST',
        '/bookings/b1/extend',
        (_) => json(201, {
          'extension': <String, dynamic>{},
          'payment': {
            'keyId': 'rzp_test_x',
            'orderId': 'order_ext',
            'amount': 2000,
            'currency': 'INR',
          },
        }),
      )
      ..on(
        'POST',
        '/bookings/b1/end',
        (_) => json(200, {'booking': bookingJson('COMPLETED')}),
      );

    final active = await repository.checkIn('b1', passCode: 'PS-7Q2K');
    final order = await repository.extend(
      'b1',
      by: const Duration(minutes: 30),
    );
    final ended = await repository.end('b1');

    expect(api.requests[0].data, {'passCode': 'PS-7Q2K'});
    expect(api.requests[1].data, {'minutes': 30});
    expect(active.status, BookingStatus.active);
    expect(order.orderId, 'order_ext');
    expect(ended.status, BookingStatus.completed);
  });
}
