import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/trips/presentation/bloc/trips_bloc.dart';
import 'package:parkspot/features/trips/presentation/screen/trips_page.dart';

import '../../helpers/mocks.dart';
import '../../helpers/pump_themed.dart';

class MockTripsBloc extends MockBloc<TripsEvent, TripsState>
    implements TripsBloc {}

void main() {
  final start = DateTime.utc(2026, 10, 19, 13);
  final live = testBooking(status: BookingStatus.active, start: start);
  final done = testBooking(id: 'b0', status: BookingStatus.completed);
  final elsewhere = Booking(
    id: 'b2',
    lotId: 'gone',
    slotLabel: 'A1',
    start: start,
    end: start.add(const Duration(hours: 1)),
    amount: done.amount,
    status: BookingStatus.cancelled,
  );

  group('bloc', () {
    late MockBookingsRepository bookings;
    late MockLotsRepository lots;

    setUp(() {
      bookings = MockBookingsRepository();
      lots = MockLotsRepository();
      when(() => lots.byId('fc')).thenAnswer((_) async => testLot());
      when(
        () => lots.byId('gone'),
      ).thenThrow(const ApiException(ApiErrorCode.notFound, 'gone'));
    });

    blocTest<TripsBloc, TripsState>(
      'splits upcoming from past and names each lot once',
      setUp: () => when(
        () => bookings.mine(),
      ).thenAnswer((_) async => [live, done, elsewhere]),
      build: () => TripsBloc(bookings: bookings, lots: lots),
      act: (bloc) => bloc.add(const TripsStarted()),
      verify: (bloc) {
        expect(bloc.state.upcoming, [live]);
        expect(bloc.state.past, [done, elsewhere]);
        expect(bloc.state.lots.keys, ['fc']);
        verify(() => lots.byId('fc')).called(1);
      },
    );

    blocTest<TripsBloc, TripsState>(
      'a failed load can be retried',
      setUp: () => when(
        () => bookings.mine(),
      ).thenThrow(const ApiException(ApiErrorCode.network, 'Offline')),
      build: () => TripsBloc(bookings: bookings, lots: lots),
      act: (bloc) => bloc.add(const TripsStarted()),
      verify: (bloc) => expect(bloc.state.error, 'Offline'),
    );
  });

  group('view', () {
    late MockTripsBloc bloc;

    setUp(() => bloc = MockTripsBloc());

    Future<void> pump(
      WidgetTester tester,
      TripsState state, {
      bool dark = false,
    }) async {
      tester.usePhoneSize();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: BlocProvider<TripsBloc>.value(
            value: bloc,
            child: TripsView(now: start.add(const Duration(minutes: 18))),
          ),
        ),
      );
    }

    final loaded = TripsState(
      loading: false,
      bookings: [live, done],
      lots: {'fc': testLot()},
    );

    for (final dark in [false, true]) {
      testWidgets('upcoming: happening now (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await pump(tester, loaded, dark: dark);

        expect(find.text('My trips'), findsOneWidget);
        expect(find.text('Happening now'), findsOneWidget);
        expect(find.text('1:42:00 left'), findsOneWidget);
        expect(find.text('FC Road Multilevel Parking · S014'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('past: status and Rebook', (tester) async {
      await pump(tester, loaded.copyWith(tab: TripsTab.past));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Rebook'), findsOneWidget);
    });

    testWidgets('tabs talk to the bloc', (tester) async {
      await pump(tester, loaded);

      await tester.tap(find.text('Past'));
      verify(() => bloc.add(const TripsTabChanged(TripsTab.past))).called(1);
    });

    testWidgets('nothing yet points to the map', (tester) async {
      await pump(tester, const TripsState(loading: false));

      expect(find.text('Nothing booked yet.'), findsOneWidget);
      expect(find.text('Find a spot on the map'), findsOneWidget);
    });
  });
}
