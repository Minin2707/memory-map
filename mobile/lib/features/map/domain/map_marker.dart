import 'package:memory_map/features/map/domain/map_coordinate.dart';

final class MapMarker {
  factory MapMarker({
    required String id,
    required MapCoordinate coordinate,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('id must not be blank');
    }

    return MapMarker._(
      id: id,
      coordinate: coordinate,
    );
  }

  const MapMarker._({
    required this.id,
    required this.coordinate,
  });

  final String id;
  final MapCoordinate coordinate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapMarker && id == other.id && coordinate == other.coordinate;
  }

  @override
  int get hashCode => Object.hash(id, coordinate);

  @override
  String toString() => 'MapMarker(hasId: true)';
}
