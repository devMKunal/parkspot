import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkspot/core/constants/app_constants.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/features/map/presentation/bloc/map_bloc.dart';
import 'package:parkspot/features/map/presentation/widgets/marker_icons.dart';

/// The Google map with a pin per visible lot. It reports where the camera
/// settled and flies to [MapState.focus]; everything else is the bloc's.
class LotsMap extends StatefulWidget {
  const LotsMap({required this.padding, super.key});

  /// Space covered by the header and the sheet, so the camera centres in
  /// the part of the map you can actually see.
  final EdgeInsets padding;

  @override
  State<LotsMap> createState() => _LotsMapState();
}

class _LotsMapState extends State<LotsMap> {
  static const _clusters = ClusterManagerId('lots');

  GoogleMapController? _controller;
  late final _icons = MarkerIcons(
    onReady: () {
      if (mounted) setState(() {});
    },
  );

  LatLng _latLng(GeoPoint p) => LatLng(p.lat, p.lng);

  Future<void> _onIdle() async {
    final controller = _controller;
    if (controller == null) return;
    final bounds = await controller.getVisibleRegion();
    final center = GeoPoint(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
    final corner = GeoPoint(
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    );
    final radius = center
        .distanceTo(corner)
        .clamp(500, AppConstants.maxNearbyRadiusMeters);
    if (mounted) context.read<MapBloc>().add(MapCameraIdle(center, radius));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return BlocConsumer<MapBloc, MapState>(
      listenWhen: (previous, current) =>
          current.focus != null && current.focus != previous.focus,
      listener: (context, state) => unawaited(
        _controller?.animateCamera(
          CameraUpdate.newLatLng(_latLng(state.focus!)),
        ),
      ),
      buildWhen: (previous, current) =>
          previous.lots != current.lots ||
          previous.query != current.query ||
          previous.selectedId != current.selectedId ||
          previous.me != current.me,
      builder: (context, state) => GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _latLng(state.focus ?? state.center),
          zoom: AppConstants.defaultMapZoom,
        ),
        style: context.isDark ? _darkStyle : null,
        padding: widget.padding,
        myLocationEnabled: state.me != null,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        clusterManagers: {const ClusterManager(clusterManagerId: _clusters)},
        markers: {
          for (final lot in state.visible)
            Marker(
              markerId: MarkerId(lot.id),
              clusterManagerId: _clusters,
              position: _latLng(lot.location),
              zIndexInt: lot.id == state.selectedId ? 1 : 0,
              icon: _icons.iconFor(
                lot,
                selected: lot.id == state.selectedId,
                theme: theme,
                pixelRatio: pixelRatio,
              ),
              onTap: () => context.read<MapBloc>().add(MapLotSelected(lot.id)),
            ),
        },
        onMapCreated: (controller) => _controller = controller,
        onCameraIdle: () => unawaited(_onIdle()),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Map colours from the dark tokens (land, roads, parks, water).
const _darkStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#161425"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#C3C0DC"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#110F1F"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2A2840"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#17301F"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#16213D"}]},
  {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';
