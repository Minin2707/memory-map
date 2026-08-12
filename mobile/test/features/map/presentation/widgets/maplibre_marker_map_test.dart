import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';

void main() {
  group('MapLibreMarkerMap contract', () {
    test('shouldAcceptCustomSourceConfigurationWithoutOpenFreeMapCoupling', () {
      final sourceConfiguration = MapSourceConfiguration(
        styleUri: 'https://example.invalid/custom-style.json',
      );
      final widget = MapLibreMarkerMap(
        markers: const [],
        sourceConfiguration: sourceConfiguration,
      );

      expect(widget.sourceConfiguration, same(sourceConfiguration));
      expect(widget.markers, isEmpty);
    });

    test('shouldAcceptDeclarativeCameraCommand', () {
      final command = MapCameraCommand(
        revision: 1,
        target: MapCameraTarget.point(
          coordinate: MapCoordinate(latitude: 41.7151, longitude: 44.8271),
          zoom: 12,
        ),
      );
      final widget = MapLibreMarkerMap(
        markers: const [],
        sourceConfiguration: MapSources.openFreeMapLiberty,
        cameraCommand: command,
      );

      expect(widget.cameraCommand, same(command));
    });
  });

  group('MapLibreMarkerMap coordinate mapping', () {
    test('shouldConvertMapCoordinateToMapLibreLatLngWithoutSwapping', () {
      final coordinate = MapCoordinate(latitude: 41.7151, longitude: 44.8271);

      final latLng = mapLibreLatLngFromMapCoordinate(coordinate);

      expect(latLng.latitude, 41.7151);
      expect(latLng.longitude, 44.8271);
    });

    test('shouldPreserveAsymmetricSouthernWesternCoordinates', () {
      final coordinate = MapCoordinate(latitude: -12.0464, longitude: -77.0428);

      final latLng = mapLibreLatLngFromMapCoordinate(coordinate);

      expect(latLng.latitude, -12.0464);
      expect(latLng.longitude, -77.0428);
    });
  });

  group('MapLibreMarkerMap camera mapping', () {
    test('shouldConvertNeutralCameraTargetToMapLibreCameraPosition', () {
      final cameraPosition = mapLibreCameraPositionFromMapCameraTarget(
        MapCameraTarget.neutral(zoom: 2),
      );

      expect(cameraPosition.target.latitude, 0);
      expect(cameraPosition.target.longitude, 0);
      expect(cameraPosition.zoom, 2);
    });

    test('shouldConvertPointCameraTargetWithoutSwappingCoordinates', () {
      final cameraPosition = mapLibreCameraPositionFromMapCameraTarget(
        MapCameraTarget.point(
          coordinate: MapCoordinate(latitude: 41.7151, longitude: 44.8271),
          zoom: 12,
        ),
      );

      expect(cameraPosition.target.latitude, 41.7151);
      expect(cameraPosition.target.longitude, 44.8271);
      expect(cameraPosition.zoom, 12);
    });
  });
}
