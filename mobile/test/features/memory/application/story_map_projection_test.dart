import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/story_map_projection.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

void main() {
  group('Story Map projection', () {
    test('shouldMapMemoryIdAndCoordinatesWithoutSwapping', () {
      final marker = mapMarkerFromMemory(
        memory(
          id: 'memory-secret-1',
          latitude: 41.7151,
          longitude: 44.8271,
        ),
      );

      expect(marker.id, 'memory-secret-1');
      expect(marker.coordinate.latitude, 41.7151);
      expect(marker.coordinate.longitude, 44.8271);
    });

    test('shouldPreserveExactInputOrderWithoutSorting', () {
      final memory3 = memory(id: 'memory-3', day: 30);
      final memory1 = memory(id: 'memory-1', day: 10);
      final memory2 = memory(id: 'memory-2', day: 20);

      final markers = mapMarkersFromMemories(<Memory>[
        memory3,
        memory1,
        memory2,
      ]);

      expect(
        markers.map((marker) => marker.id),
        <String>['memory-3', 'memory-1', 'memory-2'],
      );
    });

    test('shouldPreserveDuplicateCoordinatesAsSeparateMarkers', () {
      final first = memory(
        id: 'memory-1',
        latitude: 41.7151,
        longitude: 44.8271,
      );
      final second = memory(
        id: 'memory-2',
        latitude: 41.7151,
        longitude: 44.8271,
      );

      final markers = mapMarkersFromMemories(<Memory>[first, second]);

      expect(markers.length, 2);
      expect(markers[0].id, 'memory-1');
      expect(markers[1].id, 'memory-2');
      expect(markers[0].coordinate, markers[1].coordinate);
    });

    test('shouldPreserveDuplicateMemoryIdsOneForOne', () {
      final first = memory(id: 'memory-1', latitude: 10, longitude: 20);
      final second = memory(id: 'memory-1', latitude: 30, longitude: 40);

      final markers = mapMarkersFromMemories(<Memory>[first, second]);

      expect(markers.length, 2);
      expect(markers.map((marker) => marker.id), <String>[
        'memory-1',
        'memory-1',
      ]);
      expect(markers[0].coordinate.latitude, 10);
      expect(markers[1].coordinate.latitude, 30);
    });

    test('shouldIgnoreOptionalAndDisplayMemoryContent', () {
      final first = memory(
        id: 'memory-1',
        title: 'Original title',
        description: 'Original description',
        placeName: 'Original place',
        day: 10,
      );
      final changedContent = memory(
        id: 'memory-1',
        title: 'Changed title',
        description: null,
        placeName: null,
        day: 20,
      );

      expect(mapMarkerFromMemory(first), mapMarkerFromMemory(changedContent));
    });

    test('shouldExposeImmutableMarkerList', () {
      final markers = mapMarkersFromMemories(<Memory>[
        memory(id: 'memory-1'),
      ]);

      expect(
        () => markers.add(mapMarkerFromMemory(memory(id: 'memory-2'))),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('shouldHaveSafeDiagnosticsThroughProjectedMarkers', () {
      final markers = mapMarkersFromMemories(<Memory>[
        memory(
          id: 'memory-secret',
          storyId: 'story-secret',
          title: 'Private title',
          description: 'Private description',
          placeName: 'Private place',
          latitude: 41.715123,
          longitude: 44.827456,
        ),
      ]);

      final text = markers.toString();

      expect(text, isNot(contains('story-secret')));
      expect(text, isNot(contains('memory-secret')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
    });

    test('shouldProjectMarkerPresentationWithPhotoPreview', () {
      final preview = MemoryPhotoPreview(
        mediaId: 'private-media-id',
        thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
      );

      final presentation = storyMapMarkerPresentationFromMemoryReadModel(
        MemoryReadModel(
          memory: memory(id: 'memory-1'),
          previewPhoto: preview,
        ),
      );

      expect(presentation.marker.id, 'memory-1');
      expect(presentation.previewPhoto, preview);
      expect(presentation.hasPreviewPhoto, isTrue);
    });

    test('shouldProjectNoPhotoMarkerPresentation', () {
      final presentation = storyMapMarkerPresentationFromMemoryReadModel(
        MemoryReadModel.fromMemory(memory(id: 'memory-1')),
      );

      expect(presentation.marker.id, 'memory-1');
      expect(presentation.previewPhoto, isNull);
      expect(presentation.hasPreviewPhoto, isFalse);
    });

    test('shouldPreservePresentationOrderAndPreviewReplacement', () {
      final firstPreview = MemoryPhotoPreview(
        mediaId: 'media-a',
        thumbnailPath: '/api/v1/media/media-a/thumbnail',
      );
      final replacementPreview = MemoryPhotoPreview(
        mediaId: 'media-b',
        thumbnailPath: '/api/v1/media/media-b/thumbnail',
      );
      final first = MemoryReadModel(
        memory: memory(id: 'memory-1'),
        previewPhoto: firstPreview,
      );
      final second = MemoryReadModel.fromMemory(memory(id: 'memory-2'));

      final presentations = storyMapMarkerPresentationsFromMemoryReadModels(
        <MemoryReadModel>[
          first,
          second,
          MemoryReadModel(
            memory: memory(id: 'memory-1'),
            previewPhoto: replacementPreview,
          ),
        ],
      );

      expect(
        presentations.map((presentation) => presentation.marker.id),
        <String>['memory-1', 'memory-2', 'memory-1'],
      );
      expect(presentations[0].previewPhoto, firstPreview);
      expect(presentations[1].previewPhoto, isNull);
      expect(presentations[2].previewPhoto, replacementPreview);
    });

    test('shouldHaveSafePresentationDiagnostics', () {
      final presentation = storyMapMarkerPresentationFromMemoryReadModel(
        MemoryReadModel(
          memory: memory(
            id: 'private-memory-id',
            storyId: 'private-story-id',
            latitude: 41.715123,
            longitude: 44.827456,
          ),
          previewPhoto: MemoryPhotoPreview(
            mediaId: 'private-media-id',
            thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
          ),
        ),
      );

      final text = presentation.toString();

      expect(text, contains('hasPreviewPhoto: true'));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('/api/v1/media')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
    });
  });
}

Memory memory({
  required String id,
  String storyId = 'story-1',
  String title = 'Memory title',
  String? description = 'Memory description',
  String? placeName = 'Memory place',
  double latitude = 41.7151,
  double longitude = 44.8271,
  int day = 9,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: 'author-id',
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: latitude, longitude: longitude),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}
