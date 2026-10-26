part of 'map_bloc.dart';

enum MapStatus { loading, ready, failure }

enum MapSort {
  nearest('Nearest'),
  cheapest('Cheapest'),
  mostFree('Most free');

  const MapSort(this.label);

  final String label;
}

/// A one-off message for a snackbar: no location fix. Compared by
/// identity on purpose, so the same notice twice still shows twice.
@immutable
final class MapNotice {
  const MapNotice({required this.blocked});

  /// Permission was refused for good: offer Settings.
  final bool blocked;

  String get message => blocked
      ? 'Location is off for ParkSpot. Turn it on in Settings.'
      : "Couldn't find you. Check that location is on.";
}

@immutable
final class MapState extends Equatable {
  const MapState({
    this.status = MapStatus.loading,
    this.center = _pune,
    this.me,
    this.lots = const [],
    this.selectedId,
    this.sort = MapSort.nearest,
    this.query = '',
    this.focus,
    this.askLocation = false,
    this.notice,
    this.error,
  });

  static const _pune = GeoPoint(18.5204, 73.8567);

  final MapStatus status;

  /// Where lots were last searched for (the camera's centre).
  final GeoPoint center;

  /// The user's position, when location is allowed.
  final GeoPoint? me;
  final List<Lot> lots;
  final String? selectedId;
  final MapSort sort;
  final String query;

  /// Where the camera should fly; the view animates when this changes.
  final GeoPoint? focus;

  /// Show the location rationale (first visit only).
  final bool askLocation;
  final MapNotice? notice;
  final String? error;

  Lot? get selected => lots.where((lot) => lot.id == selectedId).firstOrNull;

  /// Metres from the user, or null when we don't know where they are.
  int? distanceTo(Lot lot) => me?.distanceTo(lot.location);

  /// Lots matching [query], in [sort] order. Markers and the sheet use this.
  List<Lot> get visible {
    final q = query.trim().toLowerCase();
    final origin = me ?? center;
    int away(Lot lot) => origin.distanceTo(lot.location);
    final matches = [
      for (final lot in lots)
        if (q.isEmpty ||
            lot.name.toLowerCase().contains(q) ||
            lot.address.toLowerCase().contains(q))
          lot,
    ];
    return matches..sort(
      (a, b) => switch (sort) {
        MapSort.nearest => away(a).compareTo(away(b)),
        MapSort.cheapest => a.pricePerHour.compareTo(b.pricePerHour),
        MapSort.mostFree => b.freeSlots.compareTo(a.freeSlots),
      }.ifZero(() => away(a).compareTo(away(b))),
    );
  }

  /// Nullable fields take a getter, so `copyWith(selectedId: () => null)`
  /// can clear them.
  MapState copyWith({
    MapStatus? status,
    GeoPoint? center,
    ValueGetter<GeoPoint?>? me,
    List<Lot>? lots,
    ValueGetter<String?>? selectedId,
    MapSort? sort,
    String? query,
    ValueGetter<GeoPoint?>? focus,
    bool? askLocation,
    ValueGetter<MapNotice?>? notice,
    ValueGetter<String?>? error,
  }) => MapState(
    status: status ?? this.status,
    center: center ?? this.center,
    me: me != null ? me() : this.me,
    lots: lots ?? this.lots,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
    sort: sort ?? this.sort,
    query: query ?? this.query,
    focus: focus != null ? focus() : this.focus,
    askLocation: askLocation ?? this.askLocation,
    // One-off: gone on the next change unless set again.
    notice: notice?.call(),
    error: error != null
        ? error()
        : (status == null || status == MapStatus.failure ? this.error : null),
  );

  @override
  List<Object?> get props => [
    status,
    center,
    me,
    lots,
    selectedId,
    sort,
    query,
    focus,
    askLocation,
    notice,
    error,
  ];
}

extension on int {
  int ifZero(int Function() then) => this == 0 ? then() : this;
}
