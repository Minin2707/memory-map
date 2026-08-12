import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

final class LocationPickerMapConfiguration {
  factory LocationPickerMapConfiguration({
    MapSourceConfiguration sourceConfiguration = MapSources.openFreeMapLiberty,
    double defaultLatitude = 0,
    double defaultLongitude = 0,
    double defaultZoom = 1.5,
    double selectedZoom = 12,
  }) {
    _validateLatitude(defaultLatitude);
    _validateLongitude(defaultLongitude);
    _validateZoom(defaultZoom, 'defaultZoom');
    _validateZoom(selectedZoom, 'selectedZoom');

    return LocationPickerMapConfiguration._(
      sourceConfiguration: sourceConfiguration,
      defaultLatitude: defaultLatitude,
      defaultLongitude: defaultLongitude,
      defaultZoom: defaultZoom,
      selectedZoom: selectedZoom,
    );
  }

  const LocationPickerMapConfiguration._({
    required this.sourceConfiguration,
    required this.defaultLatitude,
    required this.defaultLongitude,
    required this.defaultZoom,
    required this.selectedZoom,
  });

  final MapSourceConfiguration sourceConfiguration;
  final double defaultLatitude;
  final double defaultLongitude;
  final double defaultZoom;
  final double selectedZoom;

  MemoryLocation get defaultCameraLocation {
    return MemoryLocation(
      latitude: defaultLatitude,
      longitude: defaultLongitude,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LocationPickerMapConfiguration &&
            sourceConfiguration == other.sourceConfiguration &&
            defaultLatitude == other.defaultLatitude &&
            defaultLongitude == other.defaultLongitude &&
            defaultZoom == other.defaultZoom &&
            selectedZoom == other.selectedZoom;
  }

  @override
  int get hashCode => Object.hash(
        sourceConfiguration,
        defaultLatitude,
        defaultLongitude,
        defaultZoom,
        selectedZoom,
      );

  @override
  String toString() {
    return 'LocationPickerMapConfiguration(hasSourceConfiguration: true, '
        'defaultZoom: $defaultZoom, selectedZoom: $selectedZoom)';
  }

  static void _validateLatitude(double value) {
    if (!value.isFinite || value < -90.0 || value > 90.0) {
      throw ArgumentError('defaultLatitude must be between -90 and 90');
    }
  }

  static void _validateLongitude(double value) {
    if (!value.isFinite || value < -180.0 || value > 180.0) {
      throw ArgumentError('defaultLongitude must be between -180 and 180');
    }
  }

  static void _validateZoom(double value, String fieldName) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('$fieldName must not be negative');
    }
  }
}

const LocationPickerMapConfiguration
    openFreeMapLocationPickerMapConfiguration =
    LocationPickerMapConfiguration._(
  sourceConfiguration: MapSources.openFreeMapLiberty,
  defaultLatitude: 0,
  defaultLongitude: 0,
  defaultZoom: 1.5,
  selectedZoom: 12,
);
