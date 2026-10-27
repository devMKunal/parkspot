import 'dart:async';

import 'package:parkspot/core/utils/money.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// What the checkout sheet ended with. Only the server decides whether a
/// booking is paid; [CheckoutPaid] just carries the proof to verify.
sealed class CheckoutResult {
  const CheckoutResult();
}

final class CheckoutPaid extends CheckoutResult {
  const CheckoutPaid({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

/// Declined, failed or closed by the user.
final class CheckoutFailed extends CheckoutResult {
  const CheckoutFailed({required this.cancelled, this.message});

  final bool cancelled;
  final String? message;
}

/// Finished in an external wallet app; the webhook will confirm it.
final class CheckoutHandedOff extends CheckoutResult {
  const CheckoutHandedOff();
}

/// The provider's checkout UI. One implementation today (Razorpay); the
/// interface is the seam for tests and for Stripe later.
abstract interface class PaymentCheckout {
  Future<CheckoutResult> open({
    required String keyId,
    required String orderId,
    required Money amount,
    required String description,
    String? email,
    String? name,
  });
}

class RazorpayCheckout implements PaymentCheckout {
  @override
  Future<CheckoutResult> open({
    required String keyId,
    required String orderId,
    required Money amount,
    required String description,
    String? email,
    String? name,
  }) {
    final done = Completer<CheckoutResult>();
    final razorpay = Razorpay();

    void finish(CheckoutResult result) {
      if (done.isCompleted) return;
      razorpay.clear();
      done.complete(result);
    }

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        finish(
          CheckoutPaid(
            orderId: r.orderId ?? orderId,
            paymentId: r.paymentId!,
            signature: r.signature!,
          ),
        );
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        finish(
          CheckoutFailed(
            cancelled: r.code == Razorpay.PAYMENT_CANCELLED,
            message: r.message,
          ),
        );
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse _) {
        finish(const CheckoutHandedOff());
      })
      ..open({
        'key': keyId,
        'order_id': orderId,
        // The order already fixes the amount; Razorpay wants it repeated.
        'amount': amount.paise,
        'currency': amount.currency,
        'name': 'ParkSpot',
        'description': description,
        'prefill': {'email': ?email, 'name': ?name},
        'theme': {'color': '#4F46E5'},
      });
    return done.future;
  }
}
