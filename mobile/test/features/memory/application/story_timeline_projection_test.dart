import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/story_timeline_projection.dart';
import 'package:memory_map/features/memory/application/story_timeline_section.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

void main() {
  group('buildStoryTimelineSections', () {
    test('shouldReturnEmptySectionsForEmptyInput', () {
      expect(buildStoryTimelineSections(const <MemoryReadModel>[]), isEmpty);
    });

    test('shouldGroupMemoriesByYearWithNewestYearFirst', () {
      final sections = buildStoryTimelineSections(<MemoryReadModel>[
        readModel(memory(id: 'memory-2022', year: 2022, day: 7)),
        readModel(memory(id: 'memory-2024', year: 2024, day: 12)),
        readModel(memory(id: 'memory-2023', year: 2023, day: 3)),
      ]);

      expect(sections.map((section) => section.year), <int>[2024, 2023, 2022]);
    });

    test('shouldPreserveCanonicalOrderInsideYear', () {
      final older = readModel(
        memory(id: 'memory-older', year: 2024, month: 5, day: 12),
      );
      final newer = readModel(
        memory(id: 'memory-newer', year: 2024, month: 6, day: 25),
      );

      final sections = buildStoryTimelineSections(<MemoryReadModel>[
        newer,
        older,
      ]);

      expect(sections.single.memories, <MemoryReadModel>[older, newer]);
    });

    test('shouldUseCreatedAtThenIdTieBreakersForSameDate', () {
      final latestCreated = readModel(
        memory(
          id: 'memory-c',
          year: 2024,
          day: 12,
          createdAt: DateTime.utc(2026, 1, 1, 12),
        ),
      );
      final firstId = readModel(
        memory(
          id: 'memory-a',
          year: 2024,
          day: 12,
          createdAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      final secondId = readModel(
        memory(
          id: 'memory-b',
          year: 2024,
          day: 12,
          createdAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );

      final sections = buildStoryTimelineSections(<MemoryReadModel>[
        latestCreated,
        secondId,
        firstId,
      ]);

      expect(sections.single.memories, <MemoryReadModel>[
        firstId,
        secondId,
        latestCreated,
      ]);
    });

    test('shouldNotMutateSourceList', () {
      final first = readModel(memory(id: 'memory-1', year: 2024, day: 2));
      final second = readModel(memory(id: 'memory-2', year: 2023, day: 1));
      final source = <MemoryReadModel>[second, first];

      buildStoryTimelineSections(source);

      expect(source, <MemoryReadModel>[second, first]);
    });

    test('shouldPreservePreviewMetadataInItems', () {
      final preview = MemoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );
      final source = readModel(
        memory(id: 'memory-id', year: 2024),
        previewPhoto: preview,
      );

      final sections = buildStoryTimelineSections(<MemoryReadModel>[source]);

      expect(sections.single.memories.single.previewPhoto, same(preview));
    });
  });

  group('StoryTimelineSection', () {
    test('shouldExposeUnmodifiableMemoriesAndSafeDiagnostics', () {
      final section = StoryTimelineSection(
        year: 2024,
        memories: <MemoryReadModel>[
          readModel(
            memory(
              id: 'private-memory-id',
              title: 'Private title',
              placeName: 'Private place',
            ),
            previewPhoto: MemoryPhotoPreview(
              mediaId: 'private-media-id',
              thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
            ),
          ),
        ],
      );

      expect(section.memoryCount, 1);
      expect(
        () => section.memories.add(readModel(memory(id: 'another-id'))),
        throwsUnsupportedError,
      );

      final text = section.toString();

      expect(text, contains('year: 2024'));
      expect(text, contains('memoryCount: 1'));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('/api/v1/media')));
    });
  });
}

MemoryReadModel readModel(
  Memory memory, {
  MemoryPhotoPreview? previewPhoto,
}) {
  return MemoryReadModel(memory: memory, previewPhoto: previewPhoto);
}

Memory memory({
  required String id,
  int year = 2024,
  int month = 5,
  int day = 12,
  DateTime? createdAt,
  String title = 'Visible memory',
  String? placeName = 'Visible place',
}) {
  return Memory(
    id: id,
    storyId: 'story-id',
    createdBy: 'author-id',
    title: title,
    description: 'Visible description',
    placeName: placeName,
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: year, month: month, day: day),
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 1, 11),
  );
}
