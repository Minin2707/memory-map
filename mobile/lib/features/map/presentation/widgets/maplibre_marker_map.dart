import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_synchronizer.dart';

class MapLibreMarkerMap extends StatefulWidget {
  const MapLibreMarkerMap({
    required this.markers,
    required this.sourceConfiguration,
    this.cameraCommand,
    this.onMarkerSelected,
    this.selectedMarkerId,
    super.key,
  });

  final List<MapMarker> markers;
  final MapSourceConfiguration sourceConfiguration;
  final MapCameraCommand? cameraCommand;
  final ValueChanged<String>? onMarkerSelected;
  final String? selectedMarkerId;

  @override
  State<MapLibreMarkerMap> createState() => _MapLibreMarkerMapState();
}

class _MapLibreMarkerMapState extends State<MapLibreMarkerMap> {
  MapLibreMarkerSynchronizer<Circle>? _synchronizer;
  MapLibreMapController? _controller;
  int? _lastAppliedCameraRevision;

  @override
  void didUpdateWidget(MapLibreMarkerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final synchronizer = _synchronizer;
    if (synchronizer == null) {
      return;
    }

    synchronizer
      ..updateSelectionHandler(widget.onMarkerSelected)
      ..updateMarkers(
        widget.markers,
        selectedMarkerId: widget.selectedMarkerId,
      );
    if (oldWidget.cameraCommand != widget.cameraCommand) {
      unawaited(_applyCameraCommand());
    }
  }

  @override
  void dispose() {
    final synchronizer = _synchronizer;
    _synchronizer = null;
    _controller = null;
    if (synchronizer != null) {
      unawaited(synchronizer.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final synchronizer = _synchronizer;

    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          styleString: widget.sourceConfiguration.styleUri,
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            zoom: 1.5,
          ),
          compassEnabled: false,
          myLocationEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
            _synchronizer = MapLibreMarkerSynchronizer<Circle>(
              controller: _MapLibreCircleMarkerController(controller),
              onMarkerSelected: widget.onMarkerSelected,
            )..updateMarkers(
                widget.markers,
                selectedMarkerId: widget.selectedMarkerId,
              );
          },
          onStyleLoadedCallback: () {
            final changed = _synchronizer?.markStyleLoaded() ?? false;
            unawaited(_applyCameraCommand());
            if (changed && mounted) {
              setState(() {});
            }
          },
        ),
        if (synchronizer == null || synchronizer.isLoading)
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFEFF3F7)),
            child: Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFFF5D72),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _applyCameraCommand() async {
    final command = widget.cameraCommand;
    final controller = _controller;
    final synchronizer = _synchronizer;
    if (command == null ||
        controller == null ||
        synchronizer == null ||
        !synchronizer.styleLoaded ||
        _lastAppliedCameraRevision == command.revision) {
      return;
    }

    _lastAppliedCameraRevision = command.revision;
    await controller.animateCamera(
      _cameraUpdateFor(command.target),
      duration: const Duration(milliseconds: 260),
    );
  }
}

final class _MapLibreCircleMarkerController
    implements MapMarkerAnnotationController<Circle> {
  _MapLibreCircleMarkerController(this._controller);

  final MapLibreMapController _controller;

  @override
  void addMarkerTapListener(MapMarkerTapHandler<Circle> listener) {
    _controller.onCircleTapped.add(listener);
  }

  @override
  void removeMarkerTapListener(MapMarkerTapHandler<Circle> listener) {
    _controller.onCircleTapped.remove(listener);
  }

  @override
  Future<void> clearMarkers() {
    return _controller.clearCircles();
  }

  @override
  Future<List<Circle>> addMarkers(List<MapMarkerRenderOptions> options) {
    return _controller.addCircles(
      options.map(_toCircleOptions).toList(growable: false),
    );
  }
}

CircleOptions _toCircleOptions(MapMarkerRenderOptions options) {
  return CircleOptions(
    geometry: _toLatLng(options.coordinate),
    circleColor: options.selected ? '#2F3A4A' : '#FF5D72',
    circleRadius: options.selected ? 11.0 : 8.0,
    circleStrokeColor: '#FFFFFF',
    circleStrokeWidth: options.selected ? 4.0 : 3.0,
  );
}

LatLng mapLibreLatLngFromMapCoordinate(MapCoordinate coordinate) {
  return _toLatLng(coordinate);
}

CameraPosition mapLibreCameraPositionFromMapCameraTarget(
  MapCameraTarget target,
) {
  return switch (target.type) {
    MapCameraTargetType.neutral => CameraPosition(
        target: const LatLng(0, 0),
        zoom: target.zoom!,
      ),
    MapCameraTargetType.point => CameraPosition(
        target: _toLatLng(target.coordinate!),
        zoom: target.zoom!,
      ),
    MapCameraTargetType.bounds => const CameraPosition(
        target: LatLng(0, 0),
        zoom: 1.5,
      ),
  };
}

CameraUpdate _cameraUpdateFor(MapCameraTarget target) {
  return switch (target.type) {
    MapCameraTargetType.neutral => CameraUpdate.newLatLngZoom(
        const LatLng(0, 0),
        target.zoom!,
      ),
    MapCameraTargetType.point => CameraUpdate.newLatLngZoom(
        _toLatLng(target.coordinate!),
        target.zoom!,
      ),
    MapCameraTargetType.bounds => CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: _toLatLng(target.southwest!),
          northeast: _toLatLng(target.northeast!),
        ),
        left: target.padding.left,
        top: target.padding.top,
        right: target.padding.right,
        bottom: target.padding.bottom,
      ),
  };
}

LatLng _toLatLng(MapCoordinate coordinate) {
  return LatLng(coordinate.latitude, coordinate.longitude);
}
