import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/auth/domain/user.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/bookings_repository.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/lots/domain/lots_repository.dart';

part 'payment_result_event.dart';
part 'payment_result_state.dart';

/// Backs "You're parked!" and "Payment didn't go through". Both load the
/// booking from the server, so they also work from a deep link or after
/// the app was killed mid-payment.
class PaymentResultBloc extends Bloc<PaymentResultEvent, PaymentResultState> {
  PaymentResultBloc({
    required this._bookingId,
    required this._bookings,
    required this._lots,
    required this._checkout,
    this._user,
    this._pollEvery = const Duration(seconds: 3),
    this._maxPolls = 20,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const PaymentResultState()) {
    on<PaymentResultStarted>(_started);
    on<PaymentRetried>(_retry);
  }

  final String _bookingId;
  final BookingsRepository _bookings;
  final LotsRepository _lots;
  final CheckoutFlow _checkout;
  final User? _user;
  final Duration _pollEvery;
  final int _maxPolls;
  final DateTime Function() _clock;

  static const startPassed =
      'That start time has passed. Pick a new time to book again.';

  Future<void> _started(
    PaymentResultStarted event,
    Emitter<PaymentResultState> emit,
  ) async {
    emit(const PaymentResultState());
    try {
      var booking = await _bookings.get(_bookingId);
      final lot = await _lots.byId(booking.lotId);
      emit(PaymentResultState(booking: booking, lot: lot));

      // Paid but not confirmed yet: the webhook is on its way.
      for (var i = 0; i < _maxPolls && event.waitForConfirmation; i++) {
        if (booking.status != BookingStatus.pending) break;
        await Future<void>.delayed(_pollEvery);
        if (emit.isDone) return;
        booking = await _bookings.get(_bookingId);
        emit(state.copyWith(booking: booking));
      }
    } on ApiException catch (e) {
      emit(state.copyWith(error: () => e.message));
    }
  }

  Future<void> _retry(
    PaymentRetried event,
    Emitter<PaymentResultState> emit,
  ) async {
    final booking = state.booking;
    final lot = state.lot;
    if (booking == null || lot == null || state.paying.isSubmitting) return;
    // The server accepts starts up to 5 minutes in the past.
    final cutoff = _clock().subtract(const Duration(minutes: 5));
    if (booking.start.isBefore(cutoff)) {
      emit(state.copyWith(retryError: () => startPassed));
      return;
    }
    emit(
      state.copyWith(paying: SubmitStatus.submitting, retryError: () => null),
    );
    try {
      final outcome = await _checkout.pay(
        lotId: lot.id,
        lotName: lot.name,
        start: booking.start,
        duration: booking.duration,
        email: _user?.email,
        name: _user?.name,
      );
      emit(state.copyWith(paying: SubmitStatus.success, outcome: outcome));
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          paying: SubmitStatus.failure,
          retryError: () => e.message,
        ),
      );
    }
  }
}
