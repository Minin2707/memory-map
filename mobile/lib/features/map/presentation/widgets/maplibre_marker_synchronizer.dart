import 'dart:async';
import 'dart:typed_data';

import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';

typedef MapMarkerTapHandler<T extends Object> = void Function(T annotation);
typedef MapMarkerSelectedHandler = void Function(String markerId);

abstract interface class MapMarkerAnnotationController<T extends Object> {
  void addMarkerTapListener(MapMarkerTapHandler<T> listener);

  void removeMarkerTapListener(MapMarkerTapHandler<T> listener);

  void handleStyleLoaded();

  Future<void> clearMarkers();

  Future<List<T>> addMarkers(List<MapMarkerRenderOptions> options);
}

final class MapMarkerIcon {
  factory MapMarkerIcon({
    required String imageKey,
    required Uint8List bytes,
  }) {
    if (imageKey.trim().isEmpty) {
      throw ArgumentError('imageKey must not be blank');
    }

    return MapMarkerIcon._(
      imageKey: imageKey,
      bytes: bytes,
    );
  }

  const MapMarkerIcon._({
    required this.imageKey,
    required this.bytes,
  });

  final String imageKey;
  final Uint8List bytes;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapMarkerIcon && imageKey == other.imageKey;
  }

  @override
  int get hashCode => imageKey.hashCode;

  @override
  String toString() => 'MapMarkerIcon(hasBytes: true)';
}

String? resolveCompatibleMarkerIconKey({
  required String desiredImageKey,
  required Iterable<String> compatibleImageKeys,
  required bool Function(String imageKey) hasIconBytes,
}) {
  if (hasIconBytes(desiredImageKey)) {
    return desiredImageKey;
  }

  for (final imageKey in compatibleImageKeys) {
    if (hasIconBytes(imageKey)) {
      return imageKey;
    }
  }

  return null;
}

final class MapMarkerRenderOptions {
  const MapMarkerRenderOptions({
    required this.coordinate,
    required this.selected,
    this.icon,
  });

  final MapCoordinate coordinate;
  final bool selected;
  final MapMarkerIcon? icon;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapMarkerRenderOptions &&
            coordinate == other.coordinate &&
            selected == other.selected &&
            icon == other.icon;
  }

  @override
  int get hashCode => Object.hash(coordinate, selected, icon);

  @override
  String toString() {
    return 'MapMarkerRenderOptions(selected: $selected, '
        'hasIcon: ${icon != null})';
  }
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
  Map<String, MapMarkerIcon> _markerIcons = const <String, MapMarkerIcon>{};
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
    Map<String, MapMarkerIcon> markerIcons = const <String, MapMarkerIcon>{},
    String? selectedMarkerId,
  }) {
    if (_disposed) {
      return;
    }

    if (_hasSameRenderInput(markers, markerIcons, selectedMarkerId)) {
      return;
    }

    _markers = List<MapMarker>.unmodifiable(markers);
    _markerIcons = Map<String, MapMarkerIcon>.unmodifiable(markerIcons);
    _selectedMarkerId = selectedMarkerId;
    unawaited(_scheduleSync());
  }

  bool markStyleLoaded() {
    if (_disposed) {
      return false;
    }

    _controller.handleStyleLoaded();

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
            icon: _markerIcons[marker.id],
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
    Map<String, MapMarkerIcon> markerIcons,
    String? selectedMarkerId,
  ) {
    if (_selectedMarkerId != selectedMarkerId ||
        _markers.length != markers.length ||
        _markerIcons.length != markerIcons.length) {
      return false;
    }

    for (var index = 0; index < markers.length; index += 1) {
      if (_markers[index] != markers[index]) {
        return false;
      }
    }

    for (final entry in markerIcons.entries) {
      if (_markerIcons[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}
