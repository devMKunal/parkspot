import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/payment_result/presentation/bloc/payment_result_bloc.dart';
import 'package:parkspot/features/payment_result/presentation/screen/payment_failed_page.dart';
import 'package:parkspot/features/payment_result/presentation/screen/payment_success_page.dart';

import '../../helpers/mocks.dart';
import '../../helpers/pump_themed.dart';

class MockPaymentResultBloc
    extends MockBloc<PaymentResultEvent, PaymentResultState>
    implements PaymentResultBloc {}

void main() {
  late MockPaymentResultBloc bloc;

  // 6:30 to 8:30 PM IST, as UTC.
  final start = DateTime.utc(2026, 10, 19, 13);

  setUp(() => bloc = MockPaymentResultBloc());

  Future<void> pump(
    WidgetTester tester,
    Widget view, {
    bool dark = false,
  }) async {
    tester.usePhoneSize();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: BlocProvider<PaymentResultBloc>.value(value: bloc, child: view),
      ),
    );
  }

  group('success', () {
    for (final dark in [false, true]) {
      testWidgets('confirmed (${dark ? 'dark' : 'light'})', (tester) async {
        when(() => bloc.state).thenReturn(
          PaymentResultState(
            booking: testBooking(start: start),
            lot: testLot(),
          ),
        );
        await pump(tester, const PaymentSuccessView(), dark: dark);

        expect(find.text("You're parked!"), findsOneWidget);
        expect(find.textContaining('Slot S014 is all yours'), findsOneWidget);
        expect(find.text('₹80'), findsOneWidget);
        expect(find.text('Show my pass'), findsOneWidget);
        expect(find.text('Take me there'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('still confirming: says so, no pass yet', (tester) async {
      when(() => bloc.state).thenReturn(
        PaymentResultState(
          booking: testBooking(status: BookingStatus.pending),
          lot: testLot(),
        ),
      );
      await pump(tester, const PaymentSuccessView());

      expect(find.text('Confirming your payment…'), findsOneWidget);
      expect(find.text('Show my pass'), findsNothing);
    });
  });

  group('failed', () {
    final heldUntil = start.subtract(const Duration(minutes: 8));
    final pending = testBooking(
      status: BookingStatus.pending,
      start: start,
      lockExpiresAt: heldUntil,
    );

    for (final dark in [false, true]) {
      testWidgets('slot still held (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        when(
          () => bloc.state,
        ).thenReturn(PaymentResultState(booking: pending, lot: testLot()));
        await pump(
          tester,
          PaymentFailedView(
            now: heldUntil.subtract(const Duration(minutes: 5)),
          ),
          dark: dark,
        );

        expect(find.text("Payment didn't go through"), findsOneWidget);
        expect(find.textContaining('If ₹80 was debited'), findsOneWidget);
        expect(find.textContaining('is held for you until'), findsOneWidget);
        expect(find.text('Not paid'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('hold over: says it plainly; retry asks the bloc', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(PaymentResultState(booking: pending, lot: testLot()));
      await pump(
        tester,
        PaymentFailedView(now: heldUntil.add(const Duration(minutes: 1))),
      );

      expect(find.textContaining('has ended'), findsOneWidget);
      await tester.tap(find.text('Try payment again'));
      verify(() => bloc.add(const PaymentRetried())).called(1);
    });
  });
}
