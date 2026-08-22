import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/playback/presentation/map/playback_marker_projection.dart';

void main() {
  group('Playback marker projection', () {
    test('shouldReturnNoMarkersForEmptyPlaybackSnapshot', () {
      final source = <MemoryReadModel>[];

      final markers = playbackMarkersFromSnapshot(source);

      expect(markers, isEmpty);
      expect(source, isEmpty);
    });

    test('shouldCreateSingleMarkerWithSequenceNumberOne', () {
      final markers = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('memory-a'),
      ]);

      expect(markers.single.orderNumber, 1);
      expect(markers.single.marker.id, 'playback-marker-0');
    });

    test('shouldCreateOrderedMarkersFromPlaybackSnapshot', () {
      final markers = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', latitude: 41.7151, longitude: 44.8271),
        readModel('memory-b', latitude: -12.0464, longitude: -77.0428),
        readModel('memory-c', latitude: 55.751244, longitude: 37.618423),
      ]);

      expect(markers.length, 3);
      expect(markers.map((marker) => marker.orderNumber), <int>[1, 2, 3]);
      expect(markers[0].marker.coordinate, coordinate(41.7151, 44.8271));
      expect(markers[1].marker.coordinate, coordinate(-12.0464, -77.0428));
      expect(markers[2].marker.coordinate, coordinate(55.751244, 37.618423));
    });

    test('shouldUseSyntheticMarkerIdsWithoutMemoryIds', () {
      final markers = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('private-memory-a'),
        readModel('private-memory-b'),
      ]);

      expect(markers.map((marker) => marker.marker.id), <String>[
        'playback-marker-0',
        'playback-marker-1',
      ]);
    });

    test('shouldProjectPreviewPresenceWithoutLoadingMediaLists', () {
      final photo = preview('media-a');
      final markers = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('memory-a', previewPhoto: photo),
        readModel('memory-b'),
      ]);

      expect(markers[0].hasPreviewPhoto, isTrue);
      expect(markers[0].previewPhoto, same(photo));
      expect(markers[1].hasPreviewPhoto, isFalse);
      expect(markers[1].previewPhoto, isNull);
    });

    test('shouldResolveCurrentMarkerIdFromCurrentIndex', () {
      final markers = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('memory-a'),
        readModel('memory-b'),
        readModel('memory-c'),
      ]);

      expect(playbackCurrentMarkerId(markers, 1), 'playback-marker-1');
      expect(playbackCurrentMarkerId(markers, null), isNull);
      expect(playbackCurrentMarkerId(markers, -1), isNull);
      expect(playbackCurrentMarkerId(markers, 3), isNull);
    });

    test('shouldReturnImmutableMarkerList', () {
      final source = <MemoryReadModel>[
        readModel('memory-a'),
      ];
      final markers = playbackMarkersFromSnapshot(source);

      expect(
        () => markers.add(
          playbackMarkersFromSnapshot(<MemoryReadModel>[
            readModel('memory-b'),
          ]).single,
        ),
        throwsUnsupportedError,
      );
      expect(source.map((item) => item.memory.id), <String>['memory-a']);
    });

    test('shouldKeepNumberingDeterministicForSameSnapshotOrder', () {
      final snapshot = <MemoryReadModel>[
        readModel('memory-c'),
        readModel('memory-a'),
        readModel('memory-b'),
      ];

      final first = playbackMarkersFromSnapshot(snapshot);
      final second = playbackMarkersFromSnapshot(snapshot);

      expect(first, second);
      expect(first.map((marker) => marker.orderNumber), <int>[1, 2, 3]);
      expect(second.map((marker) => marker.orderNumber), <int>[1, 2, 3]);
    });

    test('shouldResolveCurrentMarkerIdWithoutMutatingMarkerList', () {
      final markers = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('memory-a'),
        readModel('memory-b'),
        readModel('memory-c'),
      ]);

      expect(playbackCurrentMarkerId(markers, 0), 'playback-marker-0');
      expect(playbackCurrentMarkerId(markers, 1), 'playback-marker-1');
      expect(playbackCurrentMarkerId(markers, 2), 'playback-marker-2');
      expect(markers.map((marker) => marker.orderNumber), <int>[1, 2, 3]);
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('private-memory-a', previewPhoto: preview('private-media-a')),
      ]).single;
      final second = playbackMarkersFromSnapshot(<MemoryReadModel>[
        readModel('private-memory-a', previewPhoto: preview('private-media-a')),
      ]).single;

      expect(first, second);
      expect(first.hashCode, second.hashCode);

      final text = first.toString();
      expect(text, contains('orderNumber: 1'));
      expect(text, contains('hasPreviewPhoto: true'));
      expect(text, isNot(contains('private-memory-a')));
      expect(text, isNot(contains('private-media-a')));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
      expect(text, isNot(contains('/api/v1/media/')));
    });
  });
}

MapCoordinate coordinate(double latitude, double longitude) {
  return MapCoordinate(latitude: latitude, longitude: longitude);
}

MemoryReadModel readModel(
  String id, {
  double latitude = 41.7151,
  double longitude = 44.8271,
  MemoryPhotoPreview? previewPhoto,
}) {
  return MemoryReadModel(
    memory: memory(id, latitude: latitude, longitude: longitude),
    previewPhoto: previewPhoto,
  );
}

Memory memory(
  String id, {
  required double latitude,
  required double longitude,
}) {
  return Memory(
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
  );
}

MemoryPhotoPreview preview(String mediaId) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}
