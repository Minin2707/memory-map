import 'dart:async';

import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';

abstract interface class PlaybackRouteAnnotationController {
  Future<void> clearRoute();

  Future<void> addRoute(PlaybackRouteRenderOptions options);
}

final class PlaybackRouteRenderOptions {
  PlaybackRouteRenderOptions({
    required List<MapCoordinate> coordinates,
    this.lineColor = playbackRouteLineColor,
    this.lineOpacity = playbackRouteLineOpacity,
    this.lineWidth = playbackRouteLineWidth,
    List<double> lineDasharray = playbackRouteLineDasharray,
  })  : coordinates = List<MapCoordinate>.unmodifiable(coordinates),
        lineDasharray = List<double>.unmodifiable(lineDasharray);

  final List<MapCoordinate> coordinates;
  final String lineColor;
  final double lineOpacity;
  final double lineWidth;
  final List<double> lineDasharray;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackRouteRenderOptions &&
            _listEquals(coordinates, other.coordinates) &&
            lineColor == other.lineColor &&
            lineOpacity == other.lineOpacity &&
            lineWidth == other.lineWidth &&
            _listEquals(lineDasharray, other.lineDasharray);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(coordinates),
        lineColor,
        lineOpacity,
        lineWidth,
        Object.hashAll(lineDasharray),
      );

  @override
  String toString() {
    return 'PlaybackRouteRenderOptions(pointCount: ${coordinates.length})';
  }
}

const String playbackRouteLineColor = '#FF5D72';
const double playbackRouteLineOpacity = 0.86;
const double playbackRouteLineWidth = 3.6;
const List<double> playbackRouteLineDasharray = <double>[1.4, 2.2];

final class PlaybackRouteSynchronizer {
  PlaybackRouteSynchronizer({
    required PlaybackRouteAnnotationController controller,
  }) : _controller = controller;

  final PlaybackRouteAnnotationController _controller;
  PlaybackRouteProjection _route = PlaybackRouteProjection();
  PlaybackRouteProjection? _lastRenderedRoute;
  bool _styleLoaded = false;
  bool _syncInProgress = false;
  bool _syncRequested = false;
  bool _disposed = false;

  bool get styleLoaded => _styleLoaded;

  bool get isLoading => !_styleLoaded;

  void updateRoute(PlaybackRouteProjection route) {
    if (_disposed) {
      return;
    }

    final nextRoute = _normalizedRoute(route);
    if (_route == nextRoute && _lastRenderedRoute == nextRoute) {
      return;
    }

    _route = nextRoute;
    unawaited(_scheduleSync());
  }

  bool markStyleLoaded() {
    if (_disposed) {
      return false;
    }

    if (_styleLoaded) {
      _lastRenderedRoute = null;
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
    _lastRenderedRoute = null;
    while (_syncInProgress) {
      await Future<void>.delayed(Duration.zero);
    }
    await _controller.clearRoute();
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
        await _syncRouteOnce();
      } while (_syncRequested && !_disposed);
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _syncRouteOnce() async {
    final route = _route;
    if (_lastRenderedRoute == route) {
      return;
    }

    await _controller.clearRoute();

    if (_disposed) {
      return;
    }

    if (!route.hasRoute) {
      _lastRenderedRoute = route;
      return;
    }

    await _controller.addRoute(
      PlaybackRouteRenderOptions(coordinates: route.coordinates),
    );

    if (!_disposed) {
      _lastRenderedRoute = route;
    }
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }

  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}

PlaybackRouteProjection _normalizedRoute(PlaybackRouteProjection route) {
  if (route.hasRoute) {
    return route;
  }

  return PlaybackRouteProjection();
}
