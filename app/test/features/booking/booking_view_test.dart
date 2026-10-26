import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:parkspot/features/booking/presentation/screen/booking_page.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';

import '../../helpers/mocks.dart';
import '../../helpers/pump_themed.dart';

class MockBookingBloc extends MockBloc<BookingEvent, BookingState>
    implements BookingBloc {}

void main() {
  late MockBookingBloc bloc;

  final now = DateTime(2026, 10, 19, 18, 22);
  final ready = BookingState(
    now: now,
    lot: testLot(),
    start: DateTime(2026, 10, 19, 18, 30),
  );

  setUp(() => bloc = MockBookingBloc());

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.usePhoneSize();
    final router = GoRouter(
      initialLocation: '/lots/fc/book',
      routes: [
        GoRoute(
          path: '/lots/fc/book',
          builder: (_, _) => BlocProvider<BookingBloc>.value(
            value: bloc,
            child: const BookingView(),
          ),
        ),
        GoRoute(
          path: '/bookings/:id/paid',
          builder: (_, s) => Text('paid ${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/bookings/:id/failed',
          builder: (_, s) => Text('failed ${s.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets('renders the design (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(ready);
      await pump(tester, dark: dark);

      expect(find.text('FC Road Multilevel Parking'), findsOneWidget);
      expect(find.text('When are you rolling in?'), findsOneWidget);
      expect(find.text('6:30 PM'), findsOneWidget);
      expect(find.text('Shopping spree'), findsOneWidget);
      expect(find.text('₹40 × 2h · 6:30 to 8:30 PM'), findsOneWidget);
      expect(find.text('₹80'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pay is disabled until the lot has loaded', (tester) async {
    when(() => bloc.state).thenReturn(BookingState(now: now));
    await pump(tester);

    final pay = tester.widget<ChunkyButton>(
      find.widgetWithText(ChunkyButton, 'Pay & park'),
    );
    expect(pay.onPressed, isNull);
  });

  testWidgets('pay, and the error when it fails', (tester) async {
    when(() => bloc.state).thenReturn(
      ready.copyWith(
        status: SubmitStatus.failure,
        error: () => BookingBloc.lotFullMessage,
      ),
    );
    await pump(tester);

    expect(
      find.widgetWithText(AlertBanner, BookingBloc.lotFullMessage),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ChunkyButton, 'Pay & park'));
    verify(() => bloc.add(const BookingPayPressed())).called(1);
  });

  for (final (outcome, page) in [
    (PayConfirmed(testBooking()), 'paid b1'),
    (PayPending(testBooking(status: BookingStatus.pending)), 'paid b1'),
    (PayNotCompleted(testBooking(status: BookingStatus.pending)), 'failed b1'),
  ]) {
    testWidgets('${outcome.runtimeType} goes to "$page"', (tester) async {
      whenListen(
        bloc,
        Stream.value(ready.copyWith(outcome: () => outcome)),
        initialState: ready,
      );
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text(page), findsOneWidget);
    });
  }
}
