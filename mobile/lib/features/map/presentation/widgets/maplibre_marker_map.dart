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

class MapLibreImageMarkerMap extends StatefulWidget {
  const MapLibreImageMarkerMap({
    required this.markers,
    required this.markerIcons,
    required this.sourceConfiguration,
    this.cameraCommand,
    this.onMarkerSelected,
    this.selectedMarkerId,
    super.key,
  });

  final List<MapMarker> markers;
  final Map<String, MapMarkerIcon> markerIcons;
  final MapSourceConfiguration sourceConfiguration;
  final MapCameraCommand? cameraCommand;
  final ValueChanged<String>? onMarkerSelected;
  final String? selectedMarkerId;

  @override
  State<MapLibreImageMarkerMap> createState() => _MapLibreImageMarkerMapState();
}

class _MapLibreImageMarkerMapState extends State<MapLibreImageMarkerMap> {
  MapLibreMarkerSynchronizer<Symbol>? _synchronizer;
  MapLibreMapController? _controller;
  int? _lastAppliedCameraRevision;

  @override
  void didUpdateWidget(MapLibreImageMarkerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final synchronizer = _synchronizer;
    if (synchronizer == null) {
      return;
    }

    synchronizer
      ..updateSelectionHandler(widget.onMarkerSelected)
      ..updateMarkers(
        widget.markers,
        markerIcons: widget.markerIcons,
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
            _synchronizer = MapLibreMarkerSynchronizer<Symbol>(
              controller: MapLibreSymbolMarkerController(controller),
              onMarkerSelected: widget.onMarkerSelected,
            )..updateMarkers(
                widget.markers,
                markerIcons: widget.markerIcons,
                selectedMarkerId: widget.selectedMarkerId,
              );
          },
          onStyleLoadedCallback: () {
            _synchronizer?.markStyleLoaded();
            unawaited(_applyCameraCommand());
            if (mounted) {
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

final class MapLibreSymbolMarkerController
    implements MapMarkerAnnotationController<Symbol> {
  MapLibreSymbolMarkerController(this._controller);

  final MapLibreMapController _controller;
  final Set<String> _registeredImageKeys = <String>{};

  @override
  void addMarkerTapListener(MapMarkerTapHandler<Symbol> listener) {
    _controller.onSymbolTapped.add(listener);
  }

  @override
  void removeMarkerTapListener(MapMarkerTapHandler<Symbol> listener) {
    _controller.onSymbolTapped.remove(listener);
  }

  @override
  Future<void> handleStyleLoaded() async {
    _registeredImageKeys.clear();
    await _controller.setSymbolIconAllowOverlap(true);
    await _controller.setSymbolIconIgnorePlacement(true);
  }

  @override
  Future<void> clearMarkers() {
    return _controller.clearSymbols();
  }

  @override
  Future<List<Symbol>> addMarkers(List<MapMarkerRenderOptions> options) async {
    final symbols = <SymbolOptions>[];

    for (final option in options) {
      final icon = option.icon;
      var iconImage = icon?.imageKey;

      if (icon != null && !_registeredImageKeys.contains(icon.imageKey)) {
        try {
          await _controller.addImage(icon.imageKey, icon.bytes);
          _registeredImageKeys.add(icon.imageKey);
        } catch (_) {
          iconImage = null;
        }
      }

      symbols.add(_toSymbolOptions(option, iconImage: iconImage));
    }

    try {
      return await _controller.addSymbols(symbols);
    } catch (_) {
      return const <Symbol>[];
    }
  }

  @override
  Future<void> updateMarker(
    Symbol annotation,
    MapMarkerRenderOptions options,
  ) async {
    final icon = options.icon;
    var iconImage = icon?.imageKey;

    if (icon != null && !_registeredImageKeys.contains(icon.imageKey)) {
      try {
        await _controller.addImage(icon.imageKey, icon.bytes);
        _registeredImageKeys.add(icon.imageKey);
      } catch (_) {
        iconImage = null;
      }
    }

    await _controller.updateSymbol(
      annotation,
      _toSymbolOptions(options, iconImage: iconImage),
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
  Future<void> handleStyleLoaded() async {}

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

  @override
  Future<void> updateMarker(
    Circle annotation,
    MapMarkerRenderOptions options,
  ) {
    return _controller.updateCircle(annotation, _toCircleOptions(options));
  }
}

SymbolOptions _toSymbolOptions(
  MapMarkerRenderOptions options, {
  required String? iconImage,
}) {
  final geometry = _toLatLng(options.coordinate);

  if (iconImage == null) {
    return SymbolOptions(
      geometry: geometry,
      textField: '\u25CF',
      textSize: options.selected ? 32.0 : 26.0,
      textColor: options.selected ? '#2F3A4A' : '#FF5D72',
      textHaloColor: '#FFFFFF',
      textHaloWidth: options.selected ? 5.0 : 4.0,
      zIndex: options.selected ? 2 : 1,
    );
  }

  return SymbolOptions(
    geometry: geometry,
    iconImage: iconImage,
    iconSize: 1.0,
    iconAnchor: 'bottom',
    zIndex: options.selected ? 2 : 1,
  );
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
