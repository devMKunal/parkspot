import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:parkspot/core/constants/app_constants.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/auth/domain/user.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/lots/domain/lots_repository.dart';

part 'booking_event.dart';
part 'booking_state.dart';

/// Booking setup: pick a start and a duration, then pay.
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc({
    required this._lotId,
    required this._lots,
    required this._checkout,
    this._user,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(BookingState(now: (clock ?? DateTime.now)())) {
    on<BookingStarted>(_started);
    on<BookingDayPicked>(
      (event, emit) => emit(_withDay(state, _dateOnly(event.day))),
    );
    on<BookingStartPicked>(
      (event, emit) => emit(state.copyWith(start: () => event.start)),
    );
    on<BookingDurationPicked>(_durationPicked);
    on<BookingDurationNudged>(
      (event, emit) => emit(
        state.copyWith(
          duration: _clampDuration(
            state.duration + AppConstants.slotStep * event.steps,
          ),
        ),
      ),
    );
    on<BookingPayPressed>(_pay);
  }

  final String _lotId;
  final LotsRepository _lots;
  final CheckoutFlow _checkout;
  final User? _user;
  final DateTime Function() _clock;

  static const lotFullMessage =
      'No free slot for that time. Try another start or a shorter stay.';

  Future<void> _started(
    BookingStarted event,
    Emitter<BookingState> emit,
  ) async {
    final now = _clock();
    var next = _withDay(state.copyWith(now: now), _dateOnly(now));
    // Late at night today has no starts left: open on tomorrow.
    if (next.starts.isEmpty) {
      next = _withDay(next, _dateOnly(now).add(const Duration(days: 1)));
    }
    emit(next);
    try {
      final lot = await _lots.byId(_lotId);
      emit(state.copyWith(lot: () => lot));
    } on ApiException catch (e) {
      emit(state.copyWith(loadError: () => e.message));
    }
  }

  /// Picks [day] and its first start, or keeps the time if it fits.
  BookingState _withDay(BookingState s, DateTime day) {
    final next = s.copyWith(day: day);
    final starts = next.starts;
    final keep = s.start != null && starts.any((t) => _sameTime(t, s.start!));
    return next.copyWith(
      start: () => keep
          ? starts.firstWhere((t) => _sameTime(t, s.start!))
          : starts.firstOrNull,
    );
  }

  static bool _sameTime(DateTime a, DateTime b) =>
      a.hour == b.hour && a.minute == b.minute;

  void _durationPicked(
    BookingDurationPicked event,
    Emitter<BookingState> emit,
  ) {
    // Tapping the chosen card again opens 15-minute fine-tuning.
    final again = event.duration == state.duration;
    emit(
      state.copyWith(
        duration: event.duration,
        fineTune: again && !state.fineTune,
      ),
    );
  }

  Future<void> _pay(BookingPayPressed event, Emitter<BookingState> emit) async {
    final lot = state.lot;
    final start = state.start;
    if (lot == null || start == null || state.status.isSubmitting) return;
    emit(state.copyWith(status: SubmitStatus.submitting, error: () => null));
    try {
      final outcome = await _checkout.pay(
        lotId: lot.id,
        lotName: lot.name,
        start: start,
        duration: state.duration,
        email: _user?.email,
        name: _user?.name,
      );
      emit(
        state.copyWith(status: SubmitStatus.success, outcome: () => outcome),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: SubmitStatus.failure,
          error: () =>
              e.code == ApiErrorCode.lotFull ? lotFullMessage : e.message,
        ),
      );
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static Duration _clampDuration(Duration d) => d < AppConstants.minBooking
      ? AppConstants.minBooking
      : (d > AppConstants.maxBooking ? AppConstants.maxBooking : d);
}
