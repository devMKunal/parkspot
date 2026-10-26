part of 'trips_bloc.dart';

enum TripsTab { upcoming, past }

@immutable
final class TripsState extends Equatable {
  const TripsState({
    this.loading = true,
    this.bookings = const [],
    this.lots = const {},
    this.tab = TripsTab.upcoming,
    this.error,
  });

  final bool loading;

  /// Newest first, as the API sends them.
  final List<Booking> bookings;
  final Map<String, Lot> lots;
  final TripsTab tab;
  final String? error;

  /// Awaiting payment, booked or checked in.
  List<Booking> get upcoming => [
    for (final b in bookings)
      if (b.status.isLive || b.status == BookingStatus.pending) b,
  ];

  List<Booking> get past => [
    for (final b in bookings)
      if (!b.status.isLive && b.status != BookingStatus.pending) b,
  ];

  TripsState copyWith({
    bool? loading,
    List<Booking>? bookings,
    Map<String, Lot>? lots,
    TripsTab? tab,
    ValueGetter<String?>? error,
  }) => TripsState(
    loading: loading ?? this.loading,
    bookings: bookings ?? this.bookings,
    lots: lots ?? this.lots,
    tab: tab ?? this.tab,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [loading, bookings, lots, tab, error];
}
