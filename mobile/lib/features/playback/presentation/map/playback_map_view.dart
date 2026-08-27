import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_synchronizer.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/presentation/map/maplibre_playback_map_camera_port.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_camera_adapter.dart';
import 'package:memory_map/features/playback/presentation/map/playback_marker_projection.dart';
import 'package:memory_map/features/playback/presentation/map/playback_marker_visual.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_synchronizer.dart';

class PlaybackMapView extends ConsumerStatefulWidget {
  const PlaybackMapView({
    required this.markers,
    required this.route,
    required this.currentIndex,
    required this.cameraCommand,
    required this.onCameraArrived,
    required this.onCameraFailed,
    this.sourceConfiguration = MapSources.openFreeMapLiberty,
    this.markerIconComposer = composePlaybackMarkerIcon,
    this.markerIconCompositionLimit =
        playbackMarkerIconCompositionConcurrencyLimit,
    super.key,
  }) : assert(markerIconCompositionLimit > 0);

  final List<PlaybackMapMarker> markers;
  final PlaybackRouteProjection route;
  final int? currentIndex;
  final PlaybackCameraCommand? cameraCommand;
  final ValueChanged<int> onCameraArrived;
  final ValueChanged<int> onCameraFailed;
  final MapSourceConfiguration sourceConfiguration;
  final PlaybackMarkerIconComposer markerIconComposer;
  final int markerIconCompositionLimit;

  @override
  ConsumerState<PlaybackMapView> createState() => _PlaybackMapViewState();
}

const PlaybackMapInteractionPolicy playbackMapInteractionPolicy =
    PlaybackMapInteractionPolicy();

const int playbackMarkerIconCompositionConcurrencyLimit = 3;

final class PlaybackMapInteractionPolicy {
  const PlaybackMapInteractionPolicy();

  bool get scrollGesturesEnabled => false;

  bool get zoomGesturesEnabled => false;

  bool get rotateGesturesEnabled => false;

  bool get tiltGesturesEnabled => false;
}

@visibleForTesting
final class PlaybackMarkerIconCompositionLimiter {
  PlaybackMarkerIconCompositionLimiter({
    required this.maxConcurrent,
  }) : assert(maxConcurrent > 0);

  final int maxConcurrent;
  final List<_PendingMarkerIconComposition> _queue =
      <_PendingMarkerIconComposition>[];
  final Set<String> _queuedKeys = <String>{};
  int _activeCount = 0;

  int get activeCount => _activeCount;

  int get queuedCount => _queue.length;

  bool get isIdle => _activeCount == 0 && _queue.isEmpty;

  bool hasQueued(String imageKey) => _queuedKeys.contains(imageKey);

  void enqueue(
    PlaybackMarkerIconRequest request,
    Future<void> Function(PlaybackMarkerIconRequest request) runner, {
    required bool priority,
  }) {
    if (_queuedKeys.contains(request.imageKey)) {
      return;
    }

    final pending = _PendingMarkerIconComposition(
      request: request,
      runner: runner,
      priority: priority,
    );
    _queuedKeys.add(request.imageKey);

    if (priority) {
      final index = _queue.indexWhere((item) => !item.priority);
      if (index == -1) {
        _queue.add(pending);
      } else {
        _queue.insert(index, pending);
      }
    } else {
      _queue.add(pending);
    }

    _drain();
  }

  void retainQueuedKeys(Set<String> relevantKeys) {
    _queue.removeWhere((pending) {
      final obsolete = !relevantKeys.contains(pending.request.imageKey);
      if (obsolete) {
        _queuedKeys.remove(pending.request.imageKey);
      }
      return obsolete;
    });
  }

  void clear() {
    _queue.clear();
    _queuedKeys.clear();
  }

  void _drain() {
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final pending = _queue.removeAt(0);
      _queuedKeys.remove(pending.request.imageKey);
      _activeCount += 1;
      unawaited(
        pending.runner(pending.request).whenComplete(() {
          _activeCount -= 1;
          _drain();
        }),
      );
    }
  }
}

final class _PendingMarkerIconComposition {
  const _PendingMarkerIconComposition({
    required this.request,
    required this.runner,
    required this.priority,
  });

  final PlaybackMarkerIconRequest request;
  final Future<void> Function(PlaybackMarkerIconRequest request) runner;
  final bool priority;
}

class _PlaybackMapViewState extends ConsumerState<PlaybackMapView> {
  late final PlaybackMapCameraAdapter _cameraAdapter;
  late final PlaybackMarkerIconCompositionLimiter _iconCompositionLimiter;
  final Map<String, Uint8List> _thumbnailBytesByPath = <String, Uint8List>{};
  final Set<String> _failedThumbnailPaths = <String>{};
  final Set<String> _loadingThumbnailPaths = <String>{};
  final Map<String, Uint8List> _iconBytesByKey = <String, Uint8List>{};
  final Set<String> _pendingIconKeys = <String>{};
  final Set<String> _failedIconKeys = <String>{};
  MapLibreMarkerSynchronizer<Symbol>? _markerSynchronizer;
  PlaybackRouteSynchronizer? _routeSynchronizer;
  Future<void> _synchronizerLifecycle = Future<void>.value();
  int _mapLifecycleGeneration = 0;

  @override
  void initState() {
    super.initState();
    _iconCompositionLimiter = PlaybackMarkerIconCompositionLimiter(
      maxConcurrent: widget.markerIconCompositionLimit,
    );
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
    if (oldWidget.markers != widget.markers) {
      _trimThumbnailState();
    }
    _startThumbnailLoads();
    final requests = _iconRequests();
    _startIconComposition(requests);
    _syncMarkers(requests);
    _routeSynchronizer?.updateRoute(widget.route);
  }

  @override
  void dispose() {
    _mapLifecycleGeneration += 1;
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
    _iconCompositionLimiter.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markerSynchronizer = _markerSynchronizer;
    _startThumbnailLoads();
    final requests = _iconRequests();
    _trimIconState(requests);
    _startIconComposition(requests);

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
            final generation = _mapLifecycleGeneration + 1;
            _mapLifecycleGeneration = generation;
            final lifecycle = _synchronizerLifecycle.then(
              (_) => _replaceMapSynchronizers(controller, generation),
            );
            _synchronizerLifecycle = lifecycle;
            unawaited(lifecycle);
          },
          onStyleLoadedCallback: () {
            unawaited(_handleStyleLoaded(_mapLifecycleGeneration));
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

  Future<void> _replaceMapSynchronizers(
    MapLibreMapController controller,
    int generation,
  ) async {
    final previousMarkerSynchronizer = _markerSynchronizer;
    final previousRouteSynchronizer = _routeSynchronizer;
    _markerSynchronizer = null;
    _routeSynchronizer = null;

    await previousMarkerSynchronizer?.dispose();
    await previousRouteSynchronizer?.dispose();
    if (!mounted || generation != _mapLifecycleGeneration) {
      return;
    }

    _cameraAdapter.attachCamera(
      MapLibrePlaybackMapCameraPort(controller),
    );
    _routeSynchronizer = PlaybackRouteSynchronizer(
      controller: _PlaybackStyleRouteController(controller),
    )..updateRoute(widget.route);

    final requests = _iconRequests();
    _markerSynchronizer = MapLibreMarkerSynchronizer<Symbol>(
      controller: MapLibreSymbolMarkerController(controller),
    )..updateMarkers(
        _renderMarkers,
        markerIcons: _markerIcons(requests),
        selectedMarkerId: _currentMarkerId,
      );
  }

  Future<void> _handleStyleLoaded(int generation) async {
    await _synchronizerLifecycle;
    if (!mounted || generation != _mapLifecycleGeneration) {
      return;
    }

    final routeChanged = _routeSynchronizer?.markStyleLoaded() ?? false;
    final markerChanged = _markerSynchronizer?.markStyleLoaded() ?? false;
    _cameraAdapter.markStyleReady();
    if ((routeChanged || markerChanged) &&
        mounted &&
        generation == _mapLifecycleGeneration) {
      setState(() {});
    }
  }

  List<MapMarker> get _renderMarkers {
    final markers = _mapMarkers;
    final currentMarkerId = _currentMarkerId;
    if (currentMarkerId == null) {
      return markers;
    }

    return <MapMarker>[
      ...markers.where((marker) => marker.id != currentMarkerId),
      ...markers.where((marker) => marker.id == currentMarkerId),
    ];
  }

  String? get _currentMarkerId {
    return playbackCurrentMarkerId(widget.markers, widget.currentIndex);
  }

  void _syncMarkers([
    Map<String, PlaybackMarkerIconRequest>? requests,
  ]) {
    _markerSynchronizer?.updateMarkers(
      _renderMarkers,
      markerIcons: _markerIcons(requests ?? _iconRequests()),
      selectedMarkerId: _currentMarkerId,
    );
  }

  Map<String, MapMarkerIcon> _markerIcons(
    Map<String, PlaybackMarkerIconRequest> requests,
  ) {
    final icons = <String, MapMarkerIcon>{};

    for (final marker in widget.markers) {
      final request = requests[marker.marker.id];
      if (request == null) {
        continue;
      }

      final imageKey = resolveCompatibleMarkerIconKey(
        desiredImageKey: request.imageKey,
        compatibleImageKeys: request.compatibleImageKeys,
        hasIconBytes: _iconBytesByKey.containsKey,
      );
      if (imageKey == null) {
        continue;
      }

      final bytes = _iconBytesByKey[imageKey];
      if (bytes == null) {
        continue;
      }

      icons[marker.marker.id] = MapMarkerIcon(
        imageKey: imageKey,
        bytes: bytes,
      );
    }

    return icons;
  }

  Map<String, PlaybackMarkerIconRequest> _iconRequests() {
    final requests = <String, PlaybackMarkerIconRequest>{};
    final currentMarkerId = _currentMarkerId;
    final pixelRatio = playbackMarkerPixelRatio(
      MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    );

    for (final marker in widget.markers) {
      final preview = marker.previewPhoto;
      final thumbnailPath = preview?.thumbnailPath;
      final thumbnailBytes = thumbnailPath == null
          ? null
          : _thumbnailBytesByPath[thumbnailPath];

      requests[marker.marker.id] = playbackMarkerIconRequest(
        sequenceNumber: marker.orderNumber,
        current: marker.marker.id == currentMarkerId,
        thumbnailPath: thumbnailPath,
        thumbnailBytes: thumbnailBytes,
        pixelRatio: pixelRatio,
      );
    }

    return requests;
  }

  void _startThumbnailLoads() {
    final paths = _currentThumbnailPaths();
    for (final path in paths) {
      if (_thumbnailBytesByPath.containsKey(path) ||
          _failedThumbnailPaths.contains(path) ||
          _loadingThumbnailPaths.contains(path)) {
        continue;
      }

      _loadingThumbnailPaths.add(path);
      unawaited(_loadThumbnail(path));
    }
  }

  Future<void> _loadThumbnail(String thumbnailPath) async {
    try {
      final bytes = await ref
          .read(mediaRepositoryProvider)
          .getThumbnailByPath(thumbnailPath);
      if (!mounted || !_currentThumbnailPaths().contains(thumbnailPath)) {
        return;
      }

      setState(() {
        _loadingThumbnailPaths.remove(thumbnailPath);
        _thumbnailBytesByPath[thumbnailPath] = bytes;
      });
      final requests = _iconRequests();
      _startIconComposition(requests);
      _syncMarkers(requests);
    } catch (_) {
      if (!mounted || !_currentThumbnailPaths().contains(thumbnailPath)) {
        return;
      }

      setState(() {
        _loadingThumbnailPaths.remove(thumbnailPath);
        _failedThumbnailPaths.add(thumbnailPath);
      });
      final requests = _iconRequests();
      _startIconComposition(requests);
      _syncMarkers(requests);
    }
  }

  void _startIconComposition(
    Map<String, PlaybackMarkerIconRequest> requests,
  ) {
    _trimIconState(requests);
    for (final request in playbackMarkerIconCompositionOrderForTesting(
      requests.values,
    )) {
      if (_iconBytesByKey.containsKey(request.imageKey) ||
          _pendingIconKeys.contains(request.imageKey) ||
          _failedIconKeys.contains(request.imageKey) ||
          _iconCompositionLimiter.hasQueued(request.imageKey)) {
        continue;
      }

      _pendingIconKeys.add(request.imageKey);
      _iconCompositionLimiter.enqueue(
        request,
        _composeIcon,
        priority: request.current,
      );
    }
  }

  Future<void> _composeIcon(PlaybackMarkerIconRequest request) async {
    try {
      if (!_isRelevantIconKey(request.imageKey)) {
        _pendingIconKeys.remove(request.imageKey);
        return;
      }

      final bytes = await widget.markerIconComposer(
        photoBytes: request.photoBytes,
        sequenceNumber: request.sequenceNumber,
        current: request.current,
        pixelRatio: request.pixelRatio,
      );
      if (!mounted) {
        return;
      }
      if (!_isRelevantIconKey(request.imageKey)) {
        setState(() {
          _pendingIconKeys.remove(request.imageKey);
        });
        return;
      }

      setState(() {
        _pendingIconKeys.remove(request.imageKey);
        _iconBytesByKey[request.imageKey] = bytes;
      });
      _syncMarkers();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingIconKeys.remove(request.imageKey);
        if (_isRelevantIconKey(request.imageKey)) {
          _failedIconKeys.add(request.imageKey);
        }
      });
      _syncMarkers();
    }
  }

  Set<String> _currentThumbnailPaths() {
    return widget.markers
        .map((marker) => marker.previewPhoto?.thumbnailPath)
        .whereType<String>()
        .toSet();
  }

  void _trimThumbnailState() {
    final currentPaths = _currentThumbnailPaths();
    _thumbnailBytesByPath.removeWhere((path, _) => !currentPaths.contains(path));
    _failedThumbnailPaths.removeWhere((path) => !currentPaths.contains(path));
    _loadingThumbnailPaths.removeWhere((path) => !currentPaths.contains(path));
  }

  void _trimIconState(Map<String, PlaybackMarkerIconRequest> requests) {
    final relevantKeys = playbackRelevantMarkerIconKeysForTesting(requests);
    _iconBytesByKey.removeWhere((key, _) => !relevantKeys.contains(key));
    _failedIconKeys.removeWhere((key) => !relevantKeys.contains(key));
    _pendingIconKeys.removeWhere((key) => !relevantKeys.contains(key));
    _iconCompositionLimiter.retainQueuedKeys(relevantKeys);
  }

  bool _isRelevantIconKey(String imageKey) {
    return playbackRelevantMarkerIconKeysForTesting(_iconRequests())
        .contains(imageKey);
  }
}

@visibleForTesting
List<PlaybackMarkerIconRequest> playbackMarkerIconCompositionOrderForTesting(
  Iterable<PlaybackMarkerIconRequest> requests,
) {
  final ordered = requests.toList(growable: false);
  ordered.sort((a, b) {
    if (a.current == b.current) {
      return 0;
    }
    return a.current ? -1 : 1;
  });
  return ordered;
}

@visibleForTesting
Set<String> playbackRelevantMarkerIconKeysForTesting(
  Map<String, PlaybackMarkerIconRequest> requests,
) {
  return <String>{
    for (final request in requests.values) ...<String>[
      request.imageKey,
      ...request.compatibleImageKeys,
    ],
  };
}

final class _PlaybackStyleRouteController
    implements PlaybackRouteAnnotationController {
  _PlaybackStyleRouteController(this._controller);

  final MapLibreMapController _controller;
  bool _hasLayer = false;
  bool _hasSource = false;

  @override
  Future<void> clearRoute() async {
    if (_hasLayer) {
      try {
        await _controller.removeLayer(_playbackRouteLayerId);
      } catch (_) {
        // A style reload may already have dropped the custom playback layer.
      } finally {
        _hasLayer = false;
      }
    }

    if (_hasSource) {
      try {
        await _controller.removeSource(_playbackRouteSourceId);
      } catch (_) {
        // A style reload may already have dropped the custom playback source.
      } finally {
        _hasSource = false;
      }
    }
  }

  @override
  Future<void> addRoute(PlaybackRouteRenderOptions options) async {
    final route = PlaybackRouteProjection(coordinates: options.coordinates);
    if (!route.hasRoute) {
      await clearRoute();
      return;
    }

    await _controller.addGeoJsonSource(
      _playbackRouteSourceId,
      _routeGeoJson(route.coordinates),
    );
    _hasSource = true;

    await _controller.addLineLayer(
      _playbackRouteSourceId,
      _playbackRouteLayerId,
      LineLayerProperties(
        lineColor: options.lineColor,
        lineOpacity: options.lineOpacity,
        lineWidth: options.lineWidth,
        lineDasharray: options.lineDasharray,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    _hasLayer = true;
  }
}

const String _playbackRouteSourceId = 'memory-map-playback-route-source';
const String _playbackRouteLayerId = 'memory-map-playback-route-layer';

@visibleForTesting
Map<String, Object> playbackRouteGeoJsonForTesting(
  List<MapCoordinate> coordinates,
) {
  return _routeGeoJson(PlaybackRouteProjection(
    coordinates: coordinates,
  ).coordinates);
}

Map<String, Object> _routeGeoJson(List<MapCoordinate> coordinates) {
  return <String, Object>{
    'type': 'FeatureCollection',
    'features': <Object>[
      <String, Object>{
        'type': 'Feature',
        'properties': <String, Object>{},
        'geometry': <String, Object>{
          'type': 'LineString',
          'coordinates': coordinates
              .map(
                (coordinate) => <double>[
                  coordinate.longitude,
                  coordinate.latitude,
                ],
              )
              .toList(growable: false),
        },
      },
    ],
  };
}
