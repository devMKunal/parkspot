import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/bookings_repository.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/lots/domain/lots_repository.dart';

part 'trips_event.dart';
part 'trips_state.dart';

/// My trips: `GET /me/bookings`, plus each lot once for its name.
class TripsBloc extends Bloc<TripsEvent, TripsState> {
  TripsBloc({required this._bookings, required this._lots})
    : super(const TripsState()) {
    on<TripsStarted>(_load);
    on<TripsTabChanged>((event, emit) => emit(state.copyWith(tab: event.tab)));
  }

  final BookingsRepository _bookings;
  final LotsRepository _lots;

  Future<void> _load(TripsStarted event, Emitter<TripsState> emit) async {
    emit(state.copyWith(loading: true, error: () => null));
    try {
      final bookings = await _bookings.mine();
      final ids = {for (final b in bookings) b.lotId};
      final lots = await Future.wait(ids.map(_lotOrNull));
      emit(
        state.copyWith(
          loading: false,
          bookings: bookings,
          lots: {for (final lot in lots.nonNulls) lot.id: lot},
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(loading: false, error: () => e.message));
    }
  }

  /// A lot that was removed shouldn't hide the whole history.
  Future<Lot?> _lotOrNull(String id) async {
    try {
      return await _lots.byId(id);
    } on ApiException {
      return null;
    }
  }
}
