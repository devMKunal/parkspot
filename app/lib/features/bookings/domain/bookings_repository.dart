import 'package:parkspot/features/bookings/domain/booking.dart';

/// The signed-in driver's bookings. Every method throws `ApiException`.
abstract interface class BookingsRepository {
  /// Holds a slot for 10 minutes and opens a payment order for it.
  Future<(Booking, PaymentOrder)> create({
    required String lotId,
    required DateTime start,
    required Duration duration,
  });

  Future<Booking> get(String id);

  /// Hands the checkout's signature to the server, which confirms.
  Future<Booking> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  });

  /// Newest first; [statuses] narrows it.
  Future<List<Booking>> mine({Set<BookingStatus>? statuses});
}
