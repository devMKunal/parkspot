import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockLotsRepository lots;
  late MockCheckoutFlow checkout;

  final evening = DateTime(2026, 10, 19, 18, 22);

  setUp(() {
    lots = MockLotsRepository();
    checkout = MockCheckoutFlow();
    when(() => lots.byId('fc')).thenAnswer((_) async => testLot());
  });

  BookingBloc build({DateTime? at}) => BookingBloc(
    lotId: 'fc',
    lots: lots,
    checkout: checkout,
    user: testUser,
    clock: () => at ?? evening,
  );

  BookingState started(DateTime now, {Duration? duration}) => BookingState(
    now: now,
    lot: testLot(),
    start: DateTime(2026, 10, 19, 18, 30),
    duration: duration ?? const Duration(hours: 2),
  );

  blocTest<BookingBloc, BookingState>(
    'opens on the next quarter hour today and loads the lot',
    build: build,
    act: (bloc) => bloc.add(const BookingStarted()),
    verify: (bloc) {
      final s = bloc.state;
      expect(s.lot, testLot());
      expect(s.start, DateTime(2026, 10, 19, 18, 30));
      expect(s.starts.first, DateTime(2026, 10, 19, 18, 30));
      expect(s.starts.last, DateTime(2026, 10, 19, 23, 45));
      // ₹40/hr × 2h, computed like the server: whole paise.
      expect(s.estimate, const Money(8000));
    },
  );

  blocTest<BookingBloc, BookingState>(
    'after the last start of the day, opens on tomorrow',
    build: () => build(at: DateTime(2026, 10, 19, 23, 50)),
    act: (bloc) => bloc.add(const BookingStarted()),
    verify: (bloc) {
      expect(bloc.state.day, DateTime(2026, 10, 20));
      expect(bloc.state.start, DateTime(2026, 10, 20));
    },
  );

  blocTest<BookingBloc, BookingState>(
    'changing the day keeps the time when it exists that day',
    build: build,
    seed: () => started(evening),
    act: (bloc) => bloc.add(BookingDayPicked(DateTime(2026, 10, 20))),
    verify: (bloc) => expect(bloc.state.start, DateTime(2026, 10, 20, 18, 30)),
  );

  blocTest<BookingBloc, BookingState>(
    'the same preset twice opens fine-tuning; steps are 15 min, clamped',
    build: build,
    seed: () => started(evening, duration: const Duration(minutes: 30)),
    act: (bloc) => bloc
      ..add(const BookingDurationPicked(Duration(minutes: 30)))
      ..add(const BookingDurationNudged(-1))
      ..add(const BookingDurationNudged(1)),
    verify: (bloc) {
      expect(bloc.state.fineTune, isTrue);
      expect(bloc.state.duration, const Duration(minutes: 45));
      // ₹40/hr × 45 min = ₹30.
      expect(bloc.state.estimate, const Money(3000));
    },
  );

  blocTest<BookingBloc, BookingState>(
    'pays with the chosen window and hands back the outcome',
    setUp: () => when(
      () => checkout.pay(
        lotId: 'fc',
        lotName: 'FC Road Multilevel Parking',
        start: DateTime(2026, 10, 19, 18, 30),
        duration: const Duration(hours: 2),
        email: 'asha@mail.com',
        name: 'Asha',
      ),
    ).thenAnswer((_) async => PayConfirmed(testBooking())),
    build: build,
    seed: () => started(evening),
    act: (bloc) => bloc.add(const BookingPayPressed()),
    expect: () => [
      isA<BookingState>().having(
        (s) => s.status,
        'status',
        SubmitStatus.submitting,
      ),
      isA<BookingState>()
          .having((s) => s.status, 'status', SubmitStatus.success)
          .having((s) => s.outcome, 'outcome', isA<PayConfirmed>()),
    ],
  );

  blocTest<BookingBloc, BookingState>(
    'a full lot gets plain advice',
    setUp: () => when(
      () => checkout.pay(
        lotId: any(named: 'lotId'),
        lotName: any(named: 'lotName'),
        start: any(named: 'start'),
        duration: any(named: 'duration'),
        email: any(named: 'email'),
        name: any(named: 'name'),
      ),
    ).thenThrow(const ApiException(ApiErrorCode.lotFull, 'full')),
    build: build,
    seed: () => started(evening),
    act: (bloc) => bloc.add(const BookingPayPressed()),
    verify: (bloc) {
      expect(bloc.state.status, SubmitStatus.failure);
      expect(bloc.state.error, BookingBloc.lotFullMessage);
    },
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Duration.zero);
  });
}
