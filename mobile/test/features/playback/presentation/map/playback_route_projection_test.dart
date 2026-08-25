import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';

void main() {
  group('Playback route projection', () {
    test('shouldReturnEmptyRouteForEmptySnapshot', () {
      final route = playbackRouteFromSnapshot(const <MemoryReadModel>[]);

      expect(route.coordinates, isEmpty);
      expect(route.hasRoute, isFalse);
    });

    test('shouldReturnNoRouteForSingleMemorySnapshot', () {
      final route = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
      ]);

      expect(route.coordinates, isEmpty);
      expect(route.hasRoute, isFalse);
    });

    test('shouldReturnNoRouteForTwoIdenticalCoordinates', () {
      final route = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-b', latitude: 41.7151, longitude: 44.8271),
      ]);

      expect(route.coordinates, isEmpty);
      expect(route.hasRoute, isFalse);
    });

    test('shouldCreateOrderedCoordinatesForMultipleMemories', () {
      final route = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-b', latitude: -12.0464, longitude: -77.0428),
        readModel('memory-c', latitude: 55.751244, longitude: 37.618423),
      ]);

      expect(route.hasRoute, isTrue);
      expect(route.coordinates, <MapCoordinate>[
        coordinate(41.7151, 44.8271),
        coordinate(-12.0464, -77.0428),
        coordinate(55.751244, 37.618423),
      ]);
    });

    test('shouldRemoveOnlyConsecutiveDuplicateCoordinates', () {
      final route = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-b', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-c', latitude: -12.0464, longitude: -77.0428),
        readModel('memory-d', latitude: -12.0464, longitude: -77.0428),
        readModel('memory-e', latitude: 55.751244, longitude: 37.618423),
      ]);

      expect(route.hasRoute, isTrue);
      expect(route.coordinates, <MapCoordinate>[
        coordinate(41.7151, 44.8271),
        coordinate(-12.0464, -77.0428),
        coordinate(55.751244, 37.618423),
      ]);
    });

    test('shouldPreserveReturnToEarlierCoordinate', () {
      final route = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-b', latitude: -12.0464, longitude: -77.0428),
        readModel('memory-c', latitude: 41.7151, longitude: 44.8271),
      ]);

      expect(route.hasRoute, isTrue);
      expect(route.coordinates, <MapCoordinate>[
        coordinate(41.7151, 44.8271),
        coordinate(-12.0464, -77.0428),
        coordinate(41.7151, 44.8271),
      ]);
    });

    test('shouldReturnNoRouteForMultipleIdenticalCoordinates', () {
      final route = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-b', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-c', latitude: 41.7151, longitude: 44.8271),
      ]);

      expect(route.coordinates, isEmpty);
      expect(route.hasRoute, isFalse);
    });

    test('shouldReturnImmutableCoordinateList', () {
      final route = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-b', latitude: -12.0464, longitude: -77.0428),
      ]);

      expect(
        () => route.coordinates.add(coordinate(55.751244, 37.618423)),
        throwsUnsupportedError,
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('private-memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('private-memory-b', latitude: -12.0464, longitude: -77.0428),
      ]);
      final second = playbackRouteFromSnapshot(<MemoryReadModel>[
        readModel('private-memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('private-memory-b', latitude: -12.0464, longitude: -77.0428),
      ]);

      expect(first, second);
      expect(first.hashCode, second.hashCode);

      final text = first.toString();
      expect(text, contains('pointCount: 2'));
      expect(text, contains('hasRoute: true'));
      expect(text, isNot(contains('private-memory-a')));
      expect(text, isNot(contains('private-memory-b')));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('-77.0428')));
    });
  });
}

MapCoordinate coordinate(double latitude, double longitude) {
  return MapCoordinate(latitude: latitude, longitude: longitude);
}

MemoryReadModel readModel(
  String id, {
  required double latitude,
  required double longitude,
}) {
  return MemoryReadModel.fromMemory(
    Memory(
      id: id,
      storyId: 'story-id',
      createdBy: 'user-id',
      title: 'Memory title',
      description: 'Memory description',
      placeName: 'Memory place',
      location: MemoryLocation(latitude: latitude, longitude: longitude),
      eventDate: MemoryDate(year: 2026, month: 8, day: 13),
      createdAt: DateTime.utc(2026, 8, 13, 10),
      updatedAt: DateTime.utc(2026, 8, 13, 11),
    ),
  );
}
