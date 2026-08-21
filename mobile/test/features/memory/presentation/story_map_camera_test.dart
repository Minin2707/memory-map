import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/presentation/story_map_camera.dart';

void main() {
  group('Story Map camera policy', () {
    test('shouldUseNeutralWorldCameraForZeroMarkers', () {
      final target = storyMapCameraTargetForMarkers(const <MapMarker>[]);

      expect(target.type, MapCameraTargetType.neutral);
      expect(target.zoom, storyMapNeutralZoom);
    });

    test('shouldCenterSingleMarkerWithDetailZoom', () {
      final target = storyMapCameraTargetForMarkers(<MapMarker>[markerA]);

      expect(target.type, MapCameraTargetType.point);
      expect(target.coordinate, markerA.coordinate);
      expect(target.zoom, storyMapSingleMarkerZoom);
    });

    test('shouldFitBoundsForManyMarkersWithoutSwappingCoordinates', () {
      final target = storyMapCameraTargetForMarkers(<MapMarker>[
        markerA,
        markerB,
        markerC,
      ]);

      expect(target.type, MapCameraTargetType.bounds);
      expect(target.southwest!.latitude, -12.0464);
      expect(target.southwest!.longitude, -77.0428);
      expect(target.northeast!.latitude, 55.751244);
      expect(target.northeast!.longitude, 44.8271);
      expect(target.padding, storyMapBoundsPadding);
      expect(target.padding.left, 56.0);
      expect(target.padding.top, 128.0);
      expect(target.padding.right, 78.0);
      expect(target.padding.bottom, 220.0);
    });

    test('shouldTreatManyMarkersWithSameCoordinateAsSinglePoint', () {
      final target = storyMapCameraTargetForMarkers(<MapMarker>[
        markerA,
        MapMarker(id: 'memory-duplicate', coordinate: markerA.coordinate),
      ]);

      expect(target.type, MapCameraTargetType.point);
      expect(target.coordinate, markerA.coordinate);
      expect(target.zoom, storyMapSingleMarkerZoom);
    });

    test('shouldBeIndependentFromMarkerOrder', () {
      final first = storyMapCameraTargetForMarkers(<MapMarker>[
        markerA,
        markerB,
        markerC,
      ]);
      final second = storyMapCameraTargetForMarkers(<MapMarker>[
        markerC,
        markerA,
        markerB,
      ]);

      expect(first, second);
    });

    test('shouldHandleExtremeValidCoordinates', () {
      final target = storyMapCameraTargetForMarkers(<MapMarker>[
        MapMarker(
          id: 'north-west',
          coordinate: MapCoordinate(latitude: 90, longitude: -180),
        ),
        MapMarker(
          id: 'south-east',
          coordinate: MapCoordinate(latitude: -90, longitude: 180),
        ),
      ]);

      expect(target.southwest!.latitude, -90);
      expect(target.southwest!.longitude, -180);
      expect(target.northeast!.latitude, 90);
      expect(target.northeast!.longitude, 180);
    });

    test('shouldHaveSafeDiagnostics', () {
      final target = storyMapCameraTargetForMarkers(<MapMarker>[markerA]);

      final text = target.toString();

      expect(text, contains('MapCameraTarget'));
      expect(text, isNot(contains('memory-a')));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
    });
  });
}

final MapMarker markerA = MapMarker(
  id: 'memory-a',
  coordinate: MapCoordinate(latitude: 41.7151, longitude: 44.8271),
);

final MapMarker markerB = MapMarker(
  id: 'memory-b',
  coordinate: MapCoordinate(latitude: -12.0464, longitude: -77.0428),
);

final MapMarker markerC = MapMarker(
  id: 'memory-c',
  coordinate: MapCoordinate(latitude: 55.751244, longitude: 37.618423),
);
