import 'package:memory_map/features/map/domain/map_coordinate.dart';

enum MapCameraTargetType {
  neutral,
  point,
  bounds,
}

final class MapCameraPadding {
  factory MapCameraPadding({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    _validatePadding(left, 'left');
    _validatePadding(top, 'top');
    _validatePadding(right, 'right');
    _validatePadding(bottom, 'bottom');

    return MapCameraPadding._(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  const MapCameraPadding._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  static const MapCameraPadding zero = MapCameraPadding._(
    left: 0,
    top: 0,
    right: 0,
    bottom: 0,
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapCameraPadding &&
            left == other.left &&
            top == other.top &&
            right == other.right &&
            bottom == other.bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'MapCameraPadding(configured: true)';

  static void _validatePadding(double value, String fieldName) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('$fieldName must not be negative');
    }
  }
}

final class MapCameraTarget {
  factory MapCameraTarget.neutral({
    double zoom = 1.5,
  }) {
    _validateZoom(zoom);

    return MapCameraTarget._(
      type: MapCameraTargetType.neutral,
      zoom: zoom,
      coordinate: null,
      southwest: null,
      northeast: null,
      padding: MapCameraPadding.zero,
    );
  }

  factory MapCameraTarget.point({
    required MapCoordinate coordinate,
    required double zoom,
  }) {
    _validateZoom(zoom);

    return MapCameraTarget._(
      type: MapCameraTargetType.point,
      zoom: zoom,
      coordinate: coordinate,
      southwest: null,
      northeast: null,
      padding: MapCameraPadding.zero,
    );
  }

  factory MapCameraTarget.bounds({
    required MapCoordinate southwest,
    required MapCoordinate northeast,
    MapCameraPadding padding = MapCameraPadding.zero,
  }) {
    if (southwest.latitude > northeast.latitude) {
      throw ArgumentError('southwest latitude must not exceed northeast');
    }
    if (southwest.longitude > northeast.longitude) {
      throw ArgumentError('southwest longitude must not exceed northeast');
    }

    return MapCameraTarget._(
      type: MapCameraTargetType.bounds,
      zoom: null,
      coordinate: null,
      southwest: southwest,
      northeast: northeast,
      padding: padding,
    );
  }

  const MapCameraTarget._({
    required this.type,
    required this.zoom,
    required this.coordinate,
    required this.southwest,
    required this.northeast,
    required this.padding,
  });

  final MapCameraTargetType type;
  final double? zoom;
  final MapCoordinate? coordinate;
  final MapCoordinate? southwest;
  final MapCoordinate? northeast;
  final MapCameraPadding padding;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapCameraTarget &&
            type == other.type &&
            zoom == other.zoom &&
            coordinate == other.coordinate &&
            southwest == other.southwest &&
            northeast == other.northeast &&
            padding == other.padding;
  }

  @override
  int get hashCode => Object.hash(
        type,
        zoom,
        coordinate,
        southwest,
        northeast,
        padding,
      );

  @override
  String toString() {
    return 'MapCameraTarget(type: $type, hasCoordinate: ${coordinate != null}, '
        'hasBounds: ${southwest != null && northeast != null})';
  }

  static void _validateZoom(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('zoom must not be negative');
    }
  }
}

final class MapCameraCommand {
  factory MapCameraCommand({
    required int revision,
    required MapCameraTarget target,
  }) {
    if (revision < 0) {
      throw ArgumentError('revision must not be negative');
    }

    return MapCameraCommand._(
      revision: revision,
      target: target,
    );
  }

  const MapCameraCommand._({
    required this.revision,
    required this.target,
  });

  final int revision;
  final MapCameraTarget target;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapCameraCommand &&
            revision == other.revision &&
            target == other.target;
  }

  @override
  int get hashCode => Object.hash(revision, target);

  @override
  String toString() {
    return 'MapCameraCommand(revision: $revision, targetType: ${target.type})';
  }
}
