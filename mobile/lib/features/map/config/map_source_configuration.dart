final class MapSourceConfiguration {
  factory MapSourceConfiguration({
    required String styleUri,
  }) {
    if (styleUri.trim().isEmpty) {
      throw ArgumentError('styleUri must not be blank');
    }

    return MapSourceConfiguration._(styleUri: styleUri);
  }

  const MapSourceConfiguration._({
    required this.styleUri,
  });

  final String styleUri;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapSourceConfiguration && styleUri == other.styleUri;
  }

  @override
  int get hashCode => styleUri.hashCode;

  @override
  String toString() => 'MapSourceConfiguration(configured: true)';
}

abstract final class MapSources {
  static const MapSourceConfiguration openFreeMapLiberty =
      MapSourceConfiguration._(
    styleUri: 'https://tiles.openfreemap.org/styles/liberty',
  );
}
