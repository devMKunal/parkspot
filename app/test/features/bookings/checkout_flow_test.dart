import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/payments/payment_checkout.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';

import '../../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Money.zero);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Duration.zero);
  });

  late MockBookingsRepository bookings;
  late MockPaymentCheckout checkout;
  late CheckoutFlow flow;

  final pending = testBooking(status: BookingStatus.pending);
  final confirmed = testBooking();
  const order = PaymentOrder(
    keyId: 'rzp_test_x',
    orderId: 'order_1',
    amount: Money(8000),
  );

  setUp(() {
    bookings = MockBookingsRepository();
    checkout = MockPaymentCheckout();
    flow = CheckoutFlow(bookings, checkout);
    when(
      () => bookings.create(
        lotId: any(named: 'lotId'),
        start: any(named: 'start'),
        duration: any(named: 'duration'),
      ),
    ).thenAnswer((_) async => (pending, order));
  });

  void checkoutEndsWith(CheckoutResult result) => when(
    () => checkout.open(
      keyId: any(named: 'keyId'),
      orderId: any(named: 'orderId'),
      amount: any(named: 'amount'),
      description: any(named: 'description'),
      email: any(named: 'email'),
      name: any(named: 'name'),
    ),
  ).thenAnswer((_) async => result);

  Future<PayOutcome> pay() => flow.pay(
    lotId: 'fc',
    lotName: 'FC Road',
    start: DateTime.utc(2026, 10, 19, 13),
    duration: const Duration(hours: 2),
    email: 'asha@mail.com',
  );

  const paid = CheckoutPaid(
    orderId: 'order_1',
    paymentId: 'pay_1',
    signature: 'sig',
  );

  test('paid and verified: confirmed, using the server order', () async {
    checkoutEndsWith(paid);
    when(
      () => bookings.verifyPayment(
        orderId: 'order_1',
        paymentId: 'pay_1',
        signature: 'sig',
      ),
    ).thenAnswer((_) async => confirmed);

    final outcome = await pay();

    expect(outcome, isA<PayConfirmed>());
    expect(outcome.booking, confirmed);
    verify(
      () => checkout.open(
        keyId: 'rzp_test_x',
        orderId: 'order_1',
        amount: const Money(8000),
        description: 'FC Road · slot S014',
        email: 'asha@mail.com',
      ),
    ).called(1);
  });

  test('declined or closed: not completed, nothing verified', () async {
    checkoutEndsWith(const CheckoutFailed(cancelled: true));

    expect(await pay(), isA<PayNotCompleted>());
    verifyNever(
      () => bookings.verifyPayment(
        orderId: any(named: 'orderId'),
        paymentId: any(named: 'paymentId'),
        signature: any(named: 'signature'),
      ),
    );
  });

  test('external wallet: pending, the webhook confirms', () async {
    checkoutEndsWith(const CheckoutHandedOff());
    expect(await pay(), isA<PayPending>());
  });

  test('paid but verify unreachable: pending, not failed', () async {
    checkoutEndsWith(paid);
    when(
      () => bookings.verifyPayment(
        orderId: any(named: 'orderId'),
        paymentId: any(named: 'paymentId'),
        signature: any(named: 'signature'),
      ),
    ).thenThrow(const ApiException(ApiErrorCode.network, 'Offline'));

    expect(await pay(), isA<PayPending>());
  });

  test('a refunded payment is an error the screen shows', () async {
    checkoutEndsWith(paid);
    when(
      () => bookings.verifyPayment(
        orderId: any(named: 'orderId'),
        paymentId: any(named: 'paymentId'),
        signature: any(named: 'signature'),
      ),
    ).thenThrow(const ApiException(ApiErrorCode.paymentRefunded, 'Refunded'));

    await expectLater(pay(), throwsA(isA<ApiException>()));
  });
}
