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

  /// The (simulated) gate scan: CONFIRMED becomes ACTIVE.
  Future<Booking> checkIn(String id, {required String passCode});

  /// Holds [by] more on the same slot and opens an order for it; paid
  /// through the same [verifyPayment].
  Future<PaymentOrder> extend(String id, {required Duration by});

  /// Leaves early: ACTIVE becomes COMPLETED and the slot frees up.
  Future<Booking> end(String id);

  /// Newest first; [statuses] narrows it.
  Future<List<Booking>> mine({Set<BookingStatus>? statuses});
}
