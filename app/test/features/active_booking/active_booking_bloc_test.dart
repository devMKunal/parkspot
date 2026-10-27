import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/active_booking/presentation/bloc/active_booking_bloc.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';

import '../../helpers/mocks.dart';

void main() {
  setUpAll(() => registerFallbackValue(testBooking()));

  late MockBookingsRepository bookings;
  late MockLotsRepository lots;
  late MockCheckoutFlow checkout;

  final confirmed = testBooking();
  final active = testBooking(status: BookingStatus.active);
  final longer = testBooking(
    status: BookingStatus.active,
    duration: const Duration(minutes: 150),
  );

  setUp(() {
    bookings = MockBookingsRepository();
    lots = MockLotsRepository();
    checkout = MockCheckoutFlow();
    when(() => bookings.get('b1')).thenAnswer((_) async => confirmed);
    when(() => lots.byId('fc')).thenAnswer((_) async => testLot());
  });

  ActiveBookingBloc build() => ActiveBookingBloc(
    bookingId: 'b1',
    bookings: bookings,
    lots: lots,
    checkout: checkout,
    confirmPollEvery: Duration.zero,
  );

  ActiveBookingState loaded(Booking b) =>
      ActiveBookingState(booking: b, lot: testLot());

  void extendEndsWith(PayOutcome outcome) => when(
    () => checkout.extend(
      booking: any(named: 'booking'),
      lotName: any(named: 'lotName'),
      by: const Duration(minutes: 30),
    ),
  ).thenAnswer((_) async => outcome);

  blocTest<ActiveBookingBloc, ActiveBookingState>(
    'loads the booking and its lot',
    build: build,
    act: (bloc) => bloc.add(const ActiveBookingStarted()),
    expect: () => [loaded(confirmed)],
  );

  blocTest<ActiveBookingBloc, ActiveBookingState>(
    'the gate scan sends the pass code and checks in',
    setUp: () => when(
      () => bookings.checkIn('b1', passCode: 'PS-7Q2K'),
    ).thenAnswer((_) async => active),
    build: build,
    seed: () => loaded(confirmed),
    act: (bloc) => bloc.add(const ActiveBookingCheckInPressed()),
    expect: () => [
      loaded(confirmed).copyWith(acting: SubmitStatus.submitting),
      loaded(active).copyWith(acting: SubmitStatus.success),
    ],
  );

  blocTest<ActiveBookingBloc, ActiveBookingState>(
    'a paid extension moves the end',
    setUp: () => extendEndsWith(PayConfirmed(longer)),
    build: build,
    seed: () => loaded(active),
    act: (bloc) =>
        bloc.add(const ActiveBookingExtendPressed(Duration(minutes: 30))),
    verify: (bloc) {
      expect(bloc.state.booking?.end, longer.end);
      expect(bloc.state.notice, 'Extended. Enjoy the extra time.');
    },
  );

  blocTest<ActiveBookingBloc, ActiveBookingState>(
    'a declined extension leaves the time as it was',
    setUp: () => extendEndsWith(PayNotCompleted(active)),
    build: build,
    seed: () => loaded(active),
    act: (bloc) =>
        bloc.add(const ActiveBookingExtendPressed(Duration(minutes: 30))),
    verify: (bloc) {
      expect(bloc.state.booking, active);
      expect(bloc.state.acting, SubmitStatus.failure);
    },
  );

  blocTest<ActiveBookingBloc, ActiveBookingState>(
    'a pending extension picks up the new end when the webhook lands',
    setUp: () {
      extendEndsWith(PayPending(active));
      final answers = [active, longer];
      when(
        () => bookings.get('b1'),
      ).thenAnswer((_) async => answers.removeAt(0));
    },
    build: build,
    seed: () => loaded(active),
    act: (bloc) =>
        bloc.add(const ActiveBookingExtendPressed(Duration(minutes: 30))),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) => expect(bloc.state.booking?.end, longer.end),
  );

  blocTest<ActiveBookingBloc, ActiveBookingState>(
    'the slot taken after you: plain advice',
    setUp: () => when(
      () => checkout.extend(
        booking: any(named: 'booking'),
        lotName: any(named: 'lotName'),
        by: any(named: 'by'),
      ),
    ).thenThrow(const ApiException(ApiErrorCode.extensionUnavailable, 'x')),
    build: build,
    seed: () => loaded(active),
    act: (bloc) =>
        bloc.add(const ActiveBookingExtendPressed(Duration(minutes: 30))),
    verify: (bloc) =>
        expect(bloc.state.notice, ActiveBookingBloc.extensionTaken),
  );

  blocTest<ActiveBookingBloc, ActiveBookingState>(
    'leaving early completes it',
    setUp: () => when(
      () => bookings.end('b1'),
    ).thenAnswer((_) async => testBooking(status: BookingStatus.completed)),
    build: build,
    seed: () => loaded(active),
    act: (bloc) => bloc.add(const ActiveBookingEndPressed()),
    verify: (bloc) =>
        expect(bloc.state.booking?.status, BookingStatus.completed),
  );

  setUpAll(() => registerFallbackValue(Duration.zero));
}
