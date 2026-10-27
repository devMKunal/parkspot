import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/location/location_service.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/map/presentation/bloc/map_bloc.dart';
import 'package:parkspot/features/map/presentation/widgets/lot_sheet.dart';
import 'package:parkspot/features/map/presentation/widgets/lots_map.dart';
import 'package:parkspot/features/map/presentation/widgets/map_header.dart';
import 'package:parkspot/router/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          MapBloc(lots: getIt(), location: getIt())..add(const MapStarted()),
      child: const MapView(),
    );
  }
}

/// Map home. [map] defaults to the Google map; widget tests swap in a box,
/// because platform views don't render in tests.
class MapView extends StatefulWidget {
  const MapView({this.map, super.key});

  final Widget? map;

  /// Roughly the header and sheet heights, so the camera centres between.
  static const mapPadding = EdgeInsets.only(top: 230, bottom: 360);

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _explainLocation() async {
    final bloc = context.read<MapBloc>();
    final granted = await context.push<bool>(AppRoutes.permission) ?? false;
    bloc.add(MapLocationAnswered(granted: granted));
    if (!granted && mounted) _searchFocus.requestFocus();
  }

  void _showNotice(MapNotice notice) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(notice.message),
          action: notice.blocked
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () =>
                      unawaited(getIt<LocationService>().openSettings()),
                )
              : null,
        ),
      );
  }

  Future<void> _directions(Lot lot) async {
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${lot.location.lat},${lot.location.lng}',
      'travelmode': 'driving',
    });
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open directions.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MapBloc, MapState>(
          listenWhen: (previous, current) =>
              current.askLocation && !previous.askLocation,
          listener: (context, _) => unawaited(_explainLocation()),
        ),
        BlocListener<MapBloc, MapState>(
          listenWhen: (previous, current) =>
              current.notice != null && current.notice != previous.notice,
          listener: (context, state) => _showNotice(state.notice!),
        ),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: widget.map ?? const LotsMap(padding: MapView.mapPadding),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: 0,
                child: SafeArea(
                  minimum: const EdgeInsets.only(top: AppSpacing.md),
                  child: MapHeader(
                    searchFocus: _searchFocus,
                    onProfile: () => context.go(AppRoutes.profile),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: ChunkyButton.icon(
                        icon: Icons.my_location_rounded,
                        semanticLabel: 'Centre on my location',
                        onPressed: () => context.read<MapBloc>().add(
                          const MapLocateRequested(),
                        ),
                      ),
                    ),
                    LotSheet(
                      onBook: (lot) => context.go(AppRoutes.book(lot.id)),
                      onDirections: (lot) => unawaited(_directions(lot)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
