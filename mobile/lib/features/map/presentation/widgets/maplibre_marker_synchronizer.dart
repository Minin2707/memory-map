import 'dart:async';

import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';

typedef MapMarkerTapHandler<T extends Object> = void Function(T annotation);
typedef MapMarkerSelectedHandler = void Function(String markerId);

abstract interface class MapMarkerAnnotationController<T extends Object> {
  void addMarkerTapListener(MapMarkerTapHandler<T> listener);

  void removeMarkerTapListener(MapMarkerTapHandler<T> listener);

  Future<void> clearMarkers();

  Future<List<T>> addMarkers(List<MapMarkerRenderOptions> options);
}

final class MapMarkerRenderOptions {
  const MapMarkerRenderOptions({
    required this.coordinate,
    required this.selected,
  });

  final MapCoordinate coordinate;
  final bool selected;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapMarkerRenderOptions &&
            coordinate == other.coordinate &&
            selected == other.selected;
  }

  @override
  int get hashCode => Object.hash(coordinate, selected);

  @override
  String toString() => 'MapMarkerRenderOptions(selected: $selected)';
}

final class MapLibreMarkerSynchronizer<T extends Object> {
  MapLibreMarkerSynchronizer({
    required MapMarkerAnnotationController<T> controller,
    MapMarkerSelectedHandler? onMarkerSelected,
  })  : _controller = controller,
        _onMarkerSelected = onMarkerSelected {
    _controller.addMarkerTapListener(_handleMarkerTapped);
  }

  final MapMarkerAnnotationController<T> _controller;
  final Map<T, String> _markerIdsByAnnotation = <T, String>{};
  MapMarkerSelectedHandler? _onMarkerSelected;
  List<MapMarker> _markers = const <MapMarker>[];
  String? _selectedMarkerId;
  bool _styleLoaded = false;
  bool _syncInProgress = false;
  bool _syncRequested = false;
  bool _disposed = false;

  bool get styleLoaded => _styleLoaded;

  bool get isLoading => !_styleLoaded;

  void updateSelectionHandler(MapMarkerSelectedHandler? onMarkerSelected) {
    _onMarkerSelected = onMarkerSelected;
  }

  void updateMarkers(
    List<MapMarker> markers, {
    String? selectedMarkerId,
  }) {
    if (_disposed) {
      return;
    }

    if (_hasSameRenderInput(markers, selectedMarkerId)) {
      return;
    }

    _markers = List<MapMarker>.unmodifiable(markers);
    _selectedMarkerId = selectedMarkerId;
    unawaited(_scheduleSync());
  }

  bool markStyleLoaded() {
    if (_disposed) {
      return false;
    }

    if (_styleLoaded) {
      unawaited(_scheduleSync());
      return false;
    }

    _styleLoaded = true;
    unawaited(_scheduleSync());
    return true;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _controller.removeMarkerTapListener(_handleMarkerTapped);
    _markerIdsByAnnotation.clear();
    await _controller.clearMarkers();
  }

  Future<void> _scheduleSync() async {
    if (!_styleLoaded || _disposed) {
      return;
    }

    if (_syncInProgress) {
      _syncRequested = true;
      return;
    }

    _syncInProgress = true;
    try {
      do {
        _syncRequested = false;
        await _syncMarkersOnce();
      } while (_syncRequested && !_disposed);
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _syncMarkersOnce() async {
    final markers = _markers;
    final selectedMarkerId = _selectedMarkerId;

    _markerIdsByAnnotation.clear();
    await _controller.clearMarkers();

    if (_disposed || markers.isEmpty) {
      return;
    }

    final options = markers
        .map(
          (marker) => MapMarkerRenderOptions(
            coordinate: marker.coordinate,
            selected: marker.id == selectedMarkerId,
          ),
        )
        .toList(growable: false);

    final annotations = await _controller.addMarkers(options);

    if (_disposed) {
      return;
    }

    final count = annotations.length < markers.length
        ? annotations.length
        : markers.length;
    for (var index = 0; index < count; index += 1) {
      _markerIdsByAnnotation[annotations[index]] = markers[index].id;
    }
  }

  void _handleMarkerTapped(T annotation) {
    if (_disposed) {
      return;
    }

    final markerId = _markerIdsByAnnotation[annotation];
    if (markerId == null) {
      return;
    }

    _onMarkerSelected?.call(markerId);
  }

  bool _hasSameRenderInput(
    List<MapMarker> markers,
    String? selectedMarkerId,
  ) {
    if (_selectedMarkerId != selectedMarkerId ||
        _markers.length != markers.length) {
      return false;
    }

    for (var index = 0; index < markers.length; index += 1) {
      if (_markers[index] != markers[index]) {
        return false;
      }
    }

    return true;
  }
}
