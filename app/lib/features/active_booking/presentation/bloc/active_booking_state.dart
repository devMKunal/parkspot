part of 'active_booking_bloc.dart';

@immutable
final class ActiveBookingState extends Equatable {
  const ActiveBookingState({
    this.booking,
    this.lot,
    this.loadError,
    this.acting = SubmitStatus.idle,
    this.notice,
  });

  final Booking? booking;
  final Lot? lot;
  final String? loadError;

  /// A check-in, extension or end in flight.
  final SubmitStatus acting;

  /// The last action's result, for a snackbar.
  final String? notice;

  ActiveBookingState copyWith({
    Booking? booking,
    Lot? lot,
    ValueGetter<String?>? loadError,
    SubmitStatus? acting,
    ValueGetter<String?>? notice,
  }) => ActiveBookingState(
    booking: booking ?? this.booking,
    lot: lot ?? this.lot,
    loadError: loadError != null ? loadError() : this.loadError,
    acting: acting ?? this.acting,
    notice: notice != null ? notice() : this.notice,
  );

  @override
  List<Object?> get props => [booking, lot, loadError, acting, notice];
}
