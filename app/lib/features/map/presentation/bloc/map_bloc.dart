import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:parkspot/core/constants/app_constants.dart';
import 'package:parkspot/core/location/location_service.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/lots/domain/lots_repository.dart';

part 'map_event.dart';
part 'map_state.dart';

/// Map home: where to look, which lots are there, which one is open in the
/// sheet. The view owns the GoogleMap and follows [MapState.focus].
class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc({
    required this._lots,
    required this._location,
    this._debounce = AppConstants.mapIdleDebounce,
  }) : super(const MapState()) {
    on<MapStarted>(_started);
    // A new pan cancels the wait (and any older request) of the previous one.
    on<MapCameraIdle>(_cameraIdle, transformer: restartable());
    on<MapRetried>((event, emit) => _load(emit, state.center, _radius));
    on<MapLotSelected>(_select);
    on<MapSortChanged>(
      (event, emit) => _pickTop(emit, state.copyWith(sort: event.sort)),
    );
    on<MapSearchChanged>(
      (event, emit) => _pickTop(emit, state.copyWith(query: event.query)),
    );
    on<MapLocateRequested>(_locate);
    on<MapLocationAnswered>(_answered);
  }

  final LotsRepository _lots;
  final LocationService _location;
  final Duration _debounce;
  int _radius = AppConstants.nearbyRadiusMeters;

  Future<void> _started(MapStarted event, Emitter<MapState> emit) async {
    final explain = await _location.shouldExplain();
    final me = explain ? null : await _location.current();
    final center = me ?? state.center;
    emit(
      state.copyWith(
        askLocation: explain,
        me: () => me,
        center: center,
        focus: () => center,
      ),
    );
    await _load(emit, center, _radius);
  }

  Future<void> _cameraIdle(MapCameraIdle event, Emitter<MapState> emit) async {
    await Future<void>.delayed(_debounce);
    _radius = event.radiusMeters;
    emit(state.copyWith(center: event.center));
    await _load(emit, event.center, event.radiusMeters);
  }

  Future<void> _load(Emitter<MapState> emit, GeoPoint at, int radius) async {
    emit(state.copyWith(status: MapStatus.loading));
    try {
      final lots = await _lots.nearby(at, radiusMeters: radius);
      final next = state.copyWith(status: MapStatus.ready, lots: lots);
      // Keep the open lot if it's still around, else open the best match.
      if (next.selected != null) return emit(next);
      final top = next.visible.firstOrNull;
      emit(next.copyWith(selectedId: () => top?.id));
    } on ApiException catch (e) {
      emit(state.copyWith(status: MapStatus.failure, error: () => e.message));
    }
  }

  Future<void> _select(MapLotSelected event, Emitter<MapState> emit) async {
    emit(state.copyWith(selectedId: () => event.lotId));
    // Refresh the free count; the list may be minutes old.
    try {
      final fresh = await _lots.byId(event.lotId);
      emit(
        state.copyWith(
          lots: [
            for (final lot in state.lots)
              if (lot.id == fresh.id) fresh else lot,
          ],
        ),
      );
    } on ApiException {
      // The sheet keeps showing the list's numbers.
    }
  }

  /// After a sort or search change: open the first lot and fly to it.
  void _pickTop(Emitter<MapState> emit, MapState next) {
    final top = next.visible.firstOrNull;
    emit(
      next.copyWith(
        selectedId: () => top?.id,
        focus: () => top?.location ?? next.focus,
      ),
    );
  }

  Future<void> _locate(MapLocateRequested event, Emitter<MapState> emit) async {
    final me = await _location.current();
    if (me == null) {
      final blocked = await _location.isBlocked();
      emit(state.copyWith(notice: () => MapNotice(blocked: blocked)));
      return;
    }
    emit(state.copyWith(me: () => me, center: me, focus: () => me));
    await _load(emit, me, _radius);
  }

  Future<void> _answered(
    MapLocationAnswered event,
    Emitter<MapState> emit,
  ) async {
    emit(state.copyWith(askLocation: false));
    if (event.granted) add(const MapLocateRequested());
  }
}
