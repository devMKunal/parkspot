import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';
import 'package:parkspot/features/payment_result/presentation/bloc/payment_result_bloc.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockBookingsRepository bookings;
  late MockLotsRepository lots;
  late MockCheckoutFlow checkout;

  final start = DateTime.utc(2026, 10, 19, 13);
  final pending = testBooking(status: BookingStatus.pending, start: start);
  final confirmed = testBooking(start: start);

  setUp(() {
    bookings = MockBookingsRepository();
    lots = MockLotsRepository();
    checkout = MockCheckoutFlow();
    when(() => lots.byId('fc')).thenAnswer((_) async => testLot());
  });

  PaymentResultBloc build({DateTime? now}) => PaymentResultBloc(
    bookingId: 'b1',
    bookings: bookings,
    lots: lots,
    checkout: checkout,
    pollEvery: Duration.zero,
    maxPolls: 3,
    clock: () => now ?? start.subtract(const Duration(minutes: 10)),
  );

  blocTest<PaymentResultBloc, PaymentResultState>(
    'waits for the webhook while the booking is pending',
    setUp: () {
      final answers = [pending, pending, confirmed];
      when(
        () => bookings.get('b1'),
      ).thenAnswer((_) async => answers.removeAt(0));
    },
    build: build,
    act: (bloc) =>
        bloc.add(const PaymentResultStarted(waitForConfirmation: true)),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.booking, confirmed);
      expect(bloc.state.lot, testLot());
      verify(() => bookings.get('b1')).called(3);
    },
  );

  blocTest<PaymentResultBloc, PaymentResultState>(
    "the failure screen doesn't poll",
    setUp: () =>
        when(() => bookings.get('b1')).thenAnswer((_) async => pending),
    build: build,
    act: (bloc) => bloc.add(const PaymentResultStarted()),
    verify: (_) => verify(() => bookings.get('b1')).called(1),
  );

  blocTest<PaymentResultBloc, PaymentResultState>(
    'try again books the same lot and time',
    setUp: () => when(
      () => checkout.pay(
        lotId: 'fc',
        lotName: 'FC Road Multilevel Parking',
        start: start,
        duration: const Duration(hours: 2),
      ),
    ).thenAnswer((_) async => PayConfirmed(confirmed)),
    build: build,
    seed: () => PaymentResultState(booking: pending, lot: testLot()),
    act: (bloc) => bloc.add(const PaymentRetried()),
    verify: (bloc) => expect(bloc.state.outcome, isA<PayConfirmed>()),
  );

  blocTest<PaymentResultBloc, PaymentResultState>(
    'a start long gone asks for a new time instead',
    build: () => build(now: start.add(const Duration(minutes: 30))),
    seed: () => PaymentResultState(booking: pending, lot: testLot()),
    act: (bloc) => bloc.add(const PaymentRetried()),
    verify: (bloc) {
      expect(bloc.state.retryError, PaymentResultBloc.startPassed);
      verifyNever(
        () => checkout.pay(
          lotId: any(named: 'lotId'),
          lotName: any(named: 'lotName'),
          start: any(named: 'start'),
          duration: any(named: 'duration'),
        ),
      );
    },
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Duration.zero);
  });
}
