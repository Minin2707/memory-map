import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

final class PlaybackRouteProjection {
  PlaybackRouteProjection({
    List<MapCoordinate> coordinates = const <MapCoordinate>[],
  }) : coordinates = List<MapCoordinate>.unmodifiable(
          _validRouteCoordinates(coordinates),
        );

  final List<MapCoordinate> coordinates;

  bool get hasRoute => coordinates.length > 1;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackRouteProjection &&
            _listEquals(coordinates, other.coordinates);
  }

  @override
  int get hashCode => Object.hashAll(coordinates);

  @override
  String toString() {
    return 'PlaybackRouteProjection(pointCount: ${coordinates.length}, '
        'hasRoute: $hasRoute)';
  }
}

PlaybackRouteProjection playbackRouteFromSnapshot(
  List<MemoryReadModel> snapshot,
) {
  if (snapshot.length < 2) {
    return PlaybackRouteProjection();
  }

  return PlaybackRouteProjection(
    coordinates: snapshot
        .map(
          (readModel) => MapCoordinate(
            latitude: readModel.memory.location.latitude,
            longitude: readModel.memory.location.longitude,
          ),
        )
        .toList(growable: false),
  );
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

List<MapCoordinate> _validRouteCoordinates(List<MapCoordinate> coordinates) {
  final normalized = <MapCoordinate>[];
  for (final coordinate in coordinates) {
    if (normalized.isEmpty || normalized.last != coordinate) {
      normalized.add(coordinate);
    }
  }

  if (normalized.length < 2) {
    return const <MapCoordinate>[];
  }

  return normalized;
}
