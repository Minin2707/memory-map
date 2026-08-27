import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/story_details_memory_projection.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

void main() {
  group('buildStoryDetailsRecentMemoryReadModels', () {
    test('shouldReturnEmptyRecentMemoriesForEmptyInput', () {
      expect(
        buildStoryDetailsRecentMemoryReadModels(const <MemoryReadModel>[]),
        isEmpty,
      );
    });

    test('shouldSelectThreeMostRecentMemoriesByReverseCanonicalOrder', () {
      final oldest = readModel(memory(id: 'memory-2021', year: 2021));
      final recent = readModel(memory(id: 'memory-2025', year: 2025));
      final newerCreated = readModel(
        memory(
          id: 'memory-c',
          year: 2024,
          createdAt: DateTime.utc(2026, 1, 1, 12),
        ),
      );
      final laterId = readModel(
        memory(
          id: 'memory-b',
          year: 2024,
          createdAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      final earlierId = readModel(
        memory(
          id: 'memory-a',
          year: 2024,
          createdAt: DateTime.utc(2026, 1, 1, 10),
        ),
      );

      final recentMemories = buildStoryDetailsRecentMemoryReadModels(
        <MemoryReadModel>[
          oldest,
          earlierId,
          recent,
          laterId,
          newerCreated,
        ],
      );

      expect(recentMemories, <MemoryReadModel>[
        recent,
        newerCreated,
        laterId,
      ]);
    });

    test('shouldNotMutateSourceListAndShouldReturnUnmodifiableResult', () {
      final first = readModel(memory(id: 'memory-1', year: 2024));
      final second = readModel(memory(id: 'memory-2', year: 2025));
      final source = <MemoryReadModel>[first, second];

      final recentMemories = buildStoryDetailsRecentMemoryReadModels(source);

      expect(source, <MemoryReadModel>[first, second]);
      expect(
        () => recentMemories.add(readModel(memory(id: 'memory-3'))),
        throwsUnsupportedError,
      );
    });

    test('shouldPreservePreviewMetadataInRecentItems', () {
      final preview = MemoryPhotoPreview(
        mediaId: 'media-id',
        thumbnailPath: '/api/v1/media/media-id/thumbnail',
      );
      final source = readModel(
        memory(id: 'memory-id', year: 2024),
        previewPhoto: preview,
      );

      final recentMemories = buildStoryDetailsRecentMemoryReadModels(
        <MemoryReadModel>[source],
      );

      expect(recentMemories.single.previewPhoto, same(preview));
    });
  });

  group('buildStoryMemoryPeriod', () {
    test('shouldReturnNullForEmptyInput', () {
      expect(buildStoryMemoryPeriod(const <MemoryReadModel>[]), isNull);
    });

    test('shouldProjectSingleMemoryYear', () {
      final period = buildStoryMemoryPeriod(<MemoryReadModel>[
        readModel(memory(id: 'memory-2024', year: 2024)),
      ]);

      expect(period?.startYear, 2024);
      expect(period?.endYear, 2024);
      expect(period?.isSingleYear, isTrue);
    });

    test('shouldProjectEarliestAndLatestMemoryEventYears', () {
      final period = buildStoryMemoryPeriod(<MemoryReadModel>[
        readModel(memory(id: 'memory-2024', year: 2024)),
        readModel(memory(id: 'memory-2021', year: 2021)),
        readModel(memory(id: 'memory-2026', year: 2026)),
      ]);

      expect(period?.startYear, 2021);
      expect(period?.endYear, 2026);
      expect(period?.isSingleYear, isFalse);
    });

    test('shouldIgnoreSourceOrderWhenProjectingPeriod', () {
      final period = buildStoryMemoryPeriod(<MemoryReadModel>[
        readModel(memory(id: 'latest', year: 2026, month: 12, day: 31)),
        readModel(memory(id: 'earliest', year: 2020, month: 1, day: 1)),
      ]);

      expect(period?.startYear, 2020);
      expect(period?.endYear, 2026);
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
}) {
  return Memory(
    id: id,
    storyId: 'story-id',
    createdBy: 'author-id',
    title: 'Visible memory',
    description: 'Visible description',
    placeName: 'Visible place',
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: year, month: month, day: day),
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 1, 11),
  );
}
