import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
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

part 'active_booking_event.dart';
part 'active_booking_state.dart';

/// The pass: check in at the gate, extend (a second payment), leave early.
/// The countdown itself is view state; this holds what the server says.
class ActiveBookingBloc extends Bloc<ActiveBookingEvent, ActiveBookingState> {
  ActiveBookingBloc({
    required this._bookingId,
    required this._bookings,
    required this._lots,
    required this._checkout,
    this._user,
    this._confirmPollEvery = const Duration(seconds: 3),
  }) : super(const ActiveBookingState()) {
    on<ActiveBookingStarted>(_load, transformer: restartable());
    // One gate action at a time; taps while one runs are dropped.
    on<ActiveBookingAction>(_act, transformer: droppable());
  }

  final String _bookingId;
  final BookingsRepository _bookings;
  final LotsRepository _lots;
  final CheckoutFlow _checkout;
  final User? _user;
  final Duration _confirmPollEvery;

  static const extensionTaken =
      'Someone has booked this slot right after you. Try a shorter extension.';

  Future<void> _load(
    ActiveBookingStarted event,
    Emitter<ActiveBookingState> emit,
  ) async {
    try {
      final booking = await _bookings.get(_bookingId);
      final lot = state.lot ?? await _lots.byId(booking.lotId);
      emit(state.copyWith(booking: booking, lot: lot, loadError: () => null));
    } on ApiException catch (e) {
      emit(state.copyWith(loadError: () => e.message));
    }
  }

  Future<void> _act(
    ActiveBookingAction event,
    Emitter<ActiveBookingState> emit,
  ) async {
    final booking = state.booking;
    final lot = state.lot;
    final passCode = booking?.passCode;
    if (booking == null || lot == null) return;
    if (event is ActiveBookingCheckInPressed && passCode == null) return;
    emit(state.copyWith(acting: SubmitStatus.submitting, notice: () => null));
    try {
      switch (event) {
        case ActiveBookingCheckInPressed():
          _done(emit, await _bookings.checkIn(booking.id, passCode: passCode!));
        case ActiveBookingEndPressed():
          _done(emit, await _bookings.end(booking.id));
        case ActiveBookingExtendPressed(:final by):
          final outcome = await _checkout.extend(
            booking: booking,
            lotName: lot.name,
            by: by,
            email: _user?.email,
            name: _user?.name,
          );
          await _extended(emit, outcome, booking);
      }
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          acting: SubmitStatus.failure,
          notice: () => e.code == ApiErrorCode.extensionUnavailable
              ? extensionTaken
              : e.message,
        ),
      );
    }
  }

  void _done(Emitter<ActiveBookingState> emit, Booking booking) =>
      emit(state.copyWith(booking: booking, acting: SubmitStatus.success));

  Future<void> _extended(
    Emitter<ActiveBookingState> emit,
    PayOutcome outcome,
    Booking before,
  ) async {
    switch (outcome) {
      case PayConfirmed(:final booking):
        emit(
          state.copyWith(
            booking: booking,
            acting: SubmitStatus.success,
            notice: () => 'Extended. Enjoy the extra time.',
          ),
        );
      case PayNotCompleted():
        emit(
          state.copyWith(
            acting: SubmitStatus.failure,
            notice: () =>
                "Payment didn't go through. Your time hasn't changed.",
          ),
        );
      case PayPending():
        emit(
          state.copyWith(
            acting: SubmitStatus.success,
            notice: () => 'Payment received. Adding your extra time…',
          ),
        );
        // The webhook confirms it; pick up the new end when it lands.
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(_confirmPollEvery);
          if (emit.isDone) return;
          final fresh = await _bookings.get(before.id);
          if (fresh.end != before.end) {
            emit(state.copyWith(booking: fresh));
            return;
          }
        }
    }
  }
}
