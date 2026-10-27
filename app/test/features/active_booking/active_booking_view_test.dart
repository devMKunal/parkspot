import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/features/active_booking/presentation/bloc/active_booking_bloc.dart';
import 'package:parkspot/features/active_booking/presentation/screen/active_booking_page.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/mocks.dart';
import '../../helpers/pump_themed.dart';

class MockActiveBookingBloc
    extends MockBloc<ActiveBookingEvent, ActiveBookingState>
    implements ActiveBookingBloc {}

void main() {
  late MockActiveBookingBloc bloc;

  final start = DateTime.utc(2026, 10, 19, 13);
  // 18 minutes in: 1:42:00 of the 2 hours left.
  final inside = start.add(const Duration(minutes: 18));

  setUp(() => bloc = MockActiveBookingBloc());

  Future<void> pump(
    WidgetTester tester,
    Booking booking, {
    bool dark = false,
    DateTime? now,
  }) async {
    tester.usePhoneSize();
    when(
      () => bloc.state,
    ).thenReturn(ActiveBookingState(booking: booking, lot: testLot()));
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: BlocProvider<ActiveBookingBloc>.value(
          value: bloc,
          child: ActiveBookingView(clock: () => now ?? inside),
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets('checked in: countdown and pass (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pump(
        tester,
        testBooking(status: BookingStatus.active, start: start),
        dark: dark,
      );

      expect(find.text('Parked & cosy'), findsOneWidget);
      expect(find.text('Checked in'), findsOneWidget);
      expect(find.text('1:42:00'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('PS-7Q2K'), findsOneWidget);
      expect(find.text('Need more time?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('before check-in: the demo gate scan', (tester) async {
    await pump(
      tester,
      testBooking(start: start),
      now: start.subtract(const Duration(minutes: 10)),
    );

    expect(find.text('Your pass is ready'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    await tester.tap(find.text('Scan at the gate'));
    verify(() => bloc.add(const ActiveBookingCheckInPressed())).called(1);
  });

  testWidgets('extend: pick a length, then pay', (tester) async {
    await pump(tester, testBooking(status: BookingStatus.active, start: start));

    await tester.tap(find.text('Need more time?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1h'));
    await tester.pump();
    await tester.tap(find.text('Pay & extend'));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(const ActiveBookingExtendPressed(Duration(hours: 1))),
    ).called(1);
  });

  testWidgets('leaving early asks first', (tester) async {
    await pump(tester, testBooking(status: BookingStatus.active, start: start));

    await tester.tap(find.text("I'm leaving early"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(const ActiveBookingEndPressed()));

    await tester.tap(find.text("I'm leaving early"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm leaving"));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const ActiveBookingEndPressed())).called(1);
  });

  testWidgets('done: no pass, offers to book again', (tester) async {
    await pump(
      tester,
      testBooking(status: BookingStatus.completed, start: start),
    );

    expect(find.text('All done'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Book here again'), findsOneWidget);
  });
}
