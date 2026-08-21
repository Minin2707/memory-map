import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_synchronizer.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/presentation/map/maplibre_playback_map_camera_port.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_camera_adapter.dart';
import 'package:memory_map/features/playback/presentation/map/playback_marker_projection.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_synchronizer.dart';

class PlaybackMapView extends StatefulWidget {
  const PlaybackMapView({
    required this.markers,
    required this.route,
    required this.currentIndex,
    required this.cameraCommand,
    required this.onCameraArrived,
    required this.onCameraFailed,
    this.sourceConfiguration = MapSources.openFreeMapLiberty,
    super.key,
  });

  final List<PlaybackMapMarker> markers;
  final PlaybackRouteProjection route;
  final int? currentIndex;
  final PlaybackCameraCommand? cameraCommand;
  final ValueChanged<int> onCameraArrived;
  final ValueChanged<int> onCameraFailed;
  final MapSourceConfiguration sourceConfiguration;

  @override
  State<PlaybackMapView> createState() => _PlaybackMapViewState();
}

const PlaybackMapInteractionPolicy playbackMapInteractionPolicy =
    PlaybackMapInteractionPolicy();

final class PlaybackMapInteractionPolicy {
  const PlaybackMapInteractionPolicy();

  bool get scrollGesturesEnabled => false;

  bool get zoomGesturesEnabled => false;

  bool get rotateGesturesEnabled => false;

  bool get tiltGesturesEnabled => false;
}

class _PlaybackMapViewState extends State<PlaybackMapView> {
  late final PlaybackMapCameraAdapter _cameraAdapter;
  MapLibreMarkerSynchronizer<Circle>? _markerSynchronizer;
  PlaybackRouteSynchronizer? _routeSynchronizer;

  @override
  void initState() {
    super.initState();
    _cameraAdapter = PlaybackMapCameraAdapter(
      onCameraArrived: (revision) {
        if (mounted) {
          widget.onCameraArrived(revision);
        }
      },
      onCameraFailed: (revision) {
        if (mounted) {
          widget.onCameraFailed(revision);
        }
      },
    )..updateCommand(widget.cameraCommand);
  }

  @override
  void didUpdateWidget(PlaybackMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraCommand != widget.cameraCommand) {
      _cameraAdapter.updateCommand(widget.cameraCommand);
    }
    _markerSynchronizer?.updateMarkers(
      _mapMarkers,
      selectedMarkerId: _currentMarkerId,
    );
    _routeSynchronizer?.updateRoute(widget.route);
  }

  @override
  void dispose() {
    _cameraAdapter.dispose();
    final markerSynchronizer = _markerSynchronizer;
    _markerSynchronizer = null;
    final routeSynchronizer = _routeSynchronizer;
    _routeSynchronizer = null;
    if (markerSynchronizer != null) {
      unawaited(markerSynchronizer.dispose());
    }
    if (routeSynchronizer != null) {
      unawaited(routeSynchronizer.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markerSynchronizer = _markerSynchronizer;

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
          scrollGesturesEnabled:
              playbackMapInteractionPolicy.scrollGesturesEnabled,
          zoomGesturesEnabled: playbackMapInteractionPolicy.zoomGesturesEnabled,
          rotateGesturesEnabled:
              playbackMapInteractionPolicy.rotateGesturesEnabled,
          tiltGesturesEnabled: playbackMapInteractionPolicy.tiltGesturesEnabled,
          onMapCreated: (controller) {
            final previousSynchronizer = _markerSynchronizer;
            if (previousSynchronizer != null) {
              unawaited(previousSynchronizer.dispose());
            }
            final previousRouteSynchronizer = _routeSynchronizer;
            if (previousRouteSynchronizer != null) {
              unawaited(previousRouteSynchronizer.dispose());
            }
            _cameraAdapter.attachCamera(
              MapLibrePlaybackMapCameraPort(controller),
            );
            _routeSynchronizer = PlaybackRouteSynchronizer(
              controller: _PlaybackLineRouteController(controller),
            )..updateRoute(widget.route);
            _markerSynchronizer = MapLibreMarkerSynchronizer<Circle>(
              controller: _PlaybackCircleMarkerController(controller),
            )..updateMarkers(
                _mapMarkers,
                selectedMarkerId: _currentMarkerId,
              );
          },
          onStyleLoadedCallback: () {
            final routeChanged =
                _routeSynchronizer?.markStyleLoaded() ?? false;
            final markerChanged =
                _markerSynchronizer?.markStyleLoaded() ?? false;
            _cameraAdapter.markStyleReady();
            if ((routeChanged || markerChanged) && mounted) {
              setState(() {});
            }
          },
        ),
        if (markerSynchronizer == null || markerSynchronizer.isLoading)
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

  List<MapMarker> get _mapMarkers {
    return widget.markers.map((marker) => marker.marker).toList(growable: false);
  }

  String? get _currentMarkerId {
    return playbackCurrentMarkerId(widget.markers, widget.currentIndex);
  }
}

final class _PlaybackLineRouteController
    implements PlaybackRouteAnnotationController {
  _PlaybackLineRouteController(this._controller);

  final MapLibreMapController _controller;

  @override
  Future<void> clearRoute() {
    return _controller.clearLines();
  }

  @override
  Future<void> addRoute(PlaybackRouteRenderOptions options) async {
    await _controller.addLine(
      LineOptions(
        geometry: options.coordinates
            .map(mapLibreLatLngFromMapCoordinate)
            .toList(growable: false),
        lineColor: options.lineColor,
        lineOpacity: options.lineOpacity,
        lineWidth: options.lineWidth,
        lineJoin: 'round',
      ),
    );
  }
}

final class _PlaybackCircleMarkerController
    implements MapMarkerAnnotationController<Circle> {
  _PlaybackCircleMarkerController(this._controller);

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
  void handleStyleLoaded() {}

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
    geometry: mapLibreLatLngFromMapCoordinate(options.coordinate),
    circleColor: options.selected ? '#2F3A4A' : '#FF5D72',
    circleRadius: options.selected ? 12.0 : 8.0,
    circleStrokeColor: '#FFFFFF',
    circleStrokeWidth: options.selected ? 4.0 : 3.0,
  );
}
