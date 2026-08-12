final class MapCoordinate {
  factory MapCoordinate({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite || latitude < -90.0 || latitude > 90.0) {
      throw ArgumentError('latitude must be between -90 and 90');
    }

    if (!longitude.isFinite || longitude < -180.0 || longitude > 180.0) {
      throw ArgumentError('longitude must be between -180 and 180');
    }

    return MapCoordinate._(
      latitude: latitude,
      longitude: longitude,
    );
  }

  const MapCoordinate._({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapCoordinate &&
            latitude == other.latitude &&
            longitude == other.longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'MapCoordinate';
}
