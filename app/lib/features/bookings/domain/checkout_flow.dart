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
    return await _payAndVerify(
      booking,
      order,
      description: '$lotName · slot ${booking.slotLabel}',
      email: email,
      name: name,
    );
  }

  /// Buys [by] more time on a live booking (a second, separate payment).
  /// [PayConfirmed] carries the booking with its new end.
  Future<PayOutcome> extend({
    required Booking booking,
    required String lotName,
    required Duration by,
    String? email,
    String? name,
  }) async {
    final order = await _bookings.extend(booking.id, by: by);
    return await _payAndVerify(
      booking,
      order,
      description: '$lotName · ${by.inMinutes} more minutes',
      email: email,
      name: name,
    );
  }

  Future<PayOutcome> _payAndVerify(
    Booking booking,
    PaymentOrder order, {
    required String description,
    String? email,
    String? name,
  }) async {
    final result = await _checkout.open(
      keyId: order.keyId,
      orderId: order.orderId,
      amount: order.amount,
      description: description,
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
