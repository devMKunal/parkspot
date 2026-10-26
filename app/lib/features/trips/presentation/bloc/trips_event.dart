part of 'trips_bloc.dart';

@immutable
sealed class TripsEvent extends Equatable {
  const TripsEvent();

  @override
  List<Object?> get props => [];
}

/// Load, pull-to-refresh and retry.
final class TripsStarted extends TripsEvent {
  const TripsStarted();
}

final class TripsTabChanged extends TripsEvent {
  const TripsTabChanged(this.tab);

  final TripsTab tab;

  @override
  List<Object?> get props => [tab];
}
