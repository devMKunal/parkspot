import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/payments/payment_checkout.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/bookings_repository.dart';

/// How a payment attempt ended, from the server's point of view.
sealed class PayOutcome {
  const PayOutcome(this.booking);

  final Booking booking;
}

/// Verified and CONFIRMED.
final class PayConfirmed extends PayOutcome {
  const PayConfirmed(super.booking);
}

/// Paid, but the confirmation hasn't reached us (offline, external
/// wallet). The webhook confirms it server-side; the next screen polls.
final class PayPending extends PayOutcome {
  const PayPending(super.booking);
}

/// Declined or closed. The slot stays held until `lockExpiresAt`.
final class PayNotCompleted extends PayOutcome {
  const PayNotCompleted(super.booking);
}

/// Book a slot and pay for it: `POST /bookings`, the provider's checkout,
/// then `POST /payments/verify`. The client never decides a booking is
/// paid; it only forwards the provider's signature.
class CheckoutFlow {
  CheckoutFlow(this._bookings, this._checkout);

  final BookingsRepository _bookings;
  final PaymentCheckout _checkout;

  /// Throws [ApiException] when no booking could be made (lot full,
  /// payments down) or the server refused the payment (refunded).
  Future<PayOutcome> pay({
    required String lotId,
    required String lotName,
    required DateTime start,
    required Duration duration,
    String? email,
    String? name,
  }) async {
    final (booking, order) = await _bookings.create(
      lotId: lotId,
      start: start,
      duration: duration,
    );
    final result = await _checkout.open(
      keyId: order.keyId,
      orderId: order.orderId,
      amount: order.amount,
      description: '$lotName · slot ${booking.slotLabel}',
      email: email,
      name: name,
    );
    switch (result) {
      case CheckoutFailed():
        return PayNotCompleted(booking);
      case CheckoutHandedOff():
        return PayPending(booking);
      case CheckoutPaid(:final orderId, :final paymentId, :final signature):
        try {
          return PayConfirmed(
            await _bookings.verifyPayment(
              orderId: orderId,
              paymentId: paymentId,
              signature: signature,
            ),
          );
        } on ApiException catch (e) {
          // The money moved; only our confirmation was lost.
          if (e.code == ApiErrorCode.network) return PayPending(booking);
          rethrow;
        }
    }
  }
}
