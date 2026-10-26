import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkspot/core/utils/availability.dart';
import 'package:parkspot/core/widgets/lot_marker.dart';
import 'package:parkspot/features/lots/domain/lot.dart';

/// [LotMarker] rendered to bitmaps for google_maps_flutter, which draws
/// markers natively. One bitmap per look (count, level, selected, theme),
/// built once and reused.
class MarkerIcons {
  MarkerIcons({required this.onReady});

  /// Called when a missing bitmap has been drawn; rebuild the markers.
  final VoidCallback onReady;

  final _cache = <String, BitmapDescriptor>{};
  final _pending = <String>{};

  /// The bitmap, or the default pin while it's being drawn.
  BitmapDescriptor iconFor(
    Lot lot, {
    required bool selected,
    required ThemeData theme,
    required double pixelRatio,
  }) {
    final level = lot.availability;
    final count = level == Availability.full ? -1 : lot.freeSlots;
    final key = '$count/${level.name}/$selected/${theme.brightness.name}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_pending.add(key)) {
      unawaited(
        _render(
          LotMarker(freeSlots: lot.freeSlots, totalSlots: lot.totalSlots),
          theme,
          pixelRatio,
        ).then((bytes) {
          // A selected pin is the same art drawn 1.25x bigger.
          _cache[key] = BitmapDescriptor.bytes(
            bytes,
            imagePixelRatio: selected ? pixelRatio / 1.25 : pixelRatio,
          );
          onReady();
        }),
      );
    }
    return BitmapDescriptor.defaultMarker;
  }

  /// Lays out and paints [widget] off screen, outside the app's tree.
  static Future<Uint8List> _render(
    Widget widget,
    ThemeData theme,
    double pixelRatio,
  ) async {
    final boundary = RenderRepaintBoundary();
    final view = WidgetsBinding.instance.platformDispatcher.implicitView!;
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.loose(const Size(160, 80)),
        devicePixelRatio: pixelRatio,
      ),
      child: RenderPositionedBox(child: boundary),
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        data: MediaQueryData(devicePixelRatio: pixelRatio),
        child: Theme(
          data: theme,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: widget,
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
