part of 'map_bloc.dart';

@immutable
sealed class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

final class MapStarted extends MapEvent {
  const MapStarted();
}

/// The camera stopped moving; look for lots in what's on screen.
final class MapCameraIdle extends MapEvent {
  const MapCameraIdle(this.center, this.radiusMeters);

  final GeoPoint center;
  final int radiusMeters;

  @override
  List<Object?> get props => [center, radiusMeters];
}

final class MapRetried extends MapEvent {
  const MapRetried();
}

final class MapLotSelected extends MapEvent {
  const MapLotSelected(this.lotId);

  final String lotId;

  @override
  List<Object?> get props => [lotId];
}

final class MapSortChanged extends MapEvent {
  const MapSortChanged(this.sort);

  final MapSort sort;

  @override
  List<Object?> get props => [sort];
}

final class MapSearchChanged extends MapEvent {
  const MapSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// "Centre on my location".
final class MapLocateRequested extends MapEvent {
  const MapLocateRequested();
}

/// Back from the location rationale.
final class MapLocationAnswered extends MapEvent {
  const MapLocationAnswered({required this.granted});

  final bool granted;

  @override
  List<Object?> get props => [granted];
}
