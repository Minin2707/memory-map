import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

void main() {
  group('StoryMemoriesState', () {
    test('shouldRepresentLoadedEmptyList', () {
      final state = StoryMemoriesState();

      expect(state.memories, isEmpty);
      expect(state.hasMemories, isFalse);
      expect(state.isLoaded, isTrue);
      expect(state.hasLoadFailure, isFalse);
      expect(state.isRefreshing, isFalse);
    });

    test('shouldCopyMemoriesIntoUnmodifiableList', () {
      final memories = <Memory>[memory(id: 'memory-1')];

      final state = StoryMemoriesState(memories: memories);
      memories.add(memory(id: 'memory-2'));

      expect(state.memories, <Memory>[memory(id: 'memory-1')]);
      expect(
        () => state.memories.add(memory(id: 'memory-3')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('shouldExposePreviewAwareReadModelsWithoutPollutingMemoryList', () {
      final preview = previewPhoto(mediaId: 'media-a');
      final readModel = MemoryReadModel(
        memory: memory(id: 'memory-1'),
        previewPhoto: preview,
      );

      final state = StoryMemoriesState(
        memoryReadModels: <MemoryReadModel>[readModel],
      );

      expect(state.memoryReadModels, <MemoryReadModel>[readModel]);
      expect(state.memoryReadModels.single.previewPhoto, same(preview));
      expect(state.memories, <Memory>[readModel.memory]);
    });

    test('shouldCopyWithAuthoritativeNullPreview', () {
      final initial = StoryMemoriesState(
        memoryReadModels: <MemoryReadModel>[
          MemoryReadModel(
            memory: memory(id: 'memory-1'),
            previewPhoto: previewPhoto(mediaId: 'media-a'),
          ),
        ],
      );
      final authoritative = MemoryReadModel(memory: memory(id: 'memory-1'));

      final copied = initial.copyWith(
        memoryReadModels: <MemoryReadModel>[authoritative],
      );

      expect(copied.memoryReadModels.single, authoritative);
      expect(copied.memoryReadModels.single.previewPhoto, isNull);
    });

    test('shouldExposeFailuresAndFlags', () {
      final state = StoryMemoriesState(
        memories: <Memory>[memory(id: 'memory-1')],
        loadFailure: const MemoryStoryUnavailable(),
        isRefreshing: true,
        refreshFailure: const MemoryRequestTimedOut(),
      );

      expect(state.hasMemories, isTrue);
      expect(state.hasLoadFailure, isTrue);
      expect(state.isLoaded, isFalse);
      expect(state.isRefreshing, isTrue);
      expect(state.refreshFailure, const MemoryRequestTimedOut());
    });

    test('shouldCopyWithUpdatedValues', () {
      final initial = StoryMemoriesState(
        memories: <Memory>[memory(id: 'memory-1')],
        loadFailure: const MemoryStoryUnavailable(),
        isRefreshing: true,
        refreshFailure: const MemoryRequestTimedOut(),
      );
      final replacement = memory(id: 'memory-2');

      final copied = initial.copyWith(
        memories: <Memory>[replacement],
        clearLoadFailure: true,
        isRefreshing: false,
        clearRefreshFailure: true,
      );

      expect(copied.memories, <Memory>[replacement]);
      expect(copied.loadFailure, isNull);
      expect(copied.isRefreshing, isFalse);
      expect(copied.refreshFailure, isNull);
    });

    test('shouldSetAndRetainNullableFailures', () {
      final state = StoryMemoriesState(
        loadFailure: const MemoryStoryUnavailable(),
        refreshFailure: const MemoryRequestTimedOut(),
      );

      final copied = state.copyWith(isRefreshing: true);

      expect(copied.loadFailure, const MemoryStoryUnavailable());
      expect(copied.refreshFailure, const MemoryRequestTimedOut());
      expect(copied.isRefreshing, isTrue);
    });

    test('shouldClearNullableFailuresExplicitly', () {
      final state = StoryMemoriesState(
        loadFailure: const MemoryStoryUnavailable(),
        refreshFailure: const MemoryRequestTimedOut(),
      );

      final copied = state.copyWith(
        clearLoadFailure: true,
        clearRefreshFailure: true,
      );

      expect(copied.loadFailure, isNull);
      expect(copied.refreshFailure, isNull);
      expect(copied.isLoaded, isTrue);
    });

    test('shouldUseDeepListEquality', () {
      final first = StoryMemoriesState(
        memories: <Memory>[memory(id: 'memory-1')],
        isRefreshing: true,
        refreshFailure: const MemoryRequestTimedOut(),
      );
      final second = StoryMemoriesState(
        memories: <Memory>[memory(id: 'memory-1')],
        isRefreshing: true,
        refreshFailure: const MemoryRequestTimedOut(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final state = StoryMemoriesState(
        memories: <Memory>[
          memory(
            id: 'private-memory-id',
            title: 'Private title',
            description: 'Private description',
            placeName: 'Private place',
          ),
        ],
        loadFailure: const MemoryNotFound(),
        refreshFailure: const MemoryNetworkUnavailable(),
      );

      final text = state.toString();

      expect(text, contains('memoryCount: 1'));
      expect(text, contains('hasLoadFailure: true'));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('55.751244')));
      expect(text, isNot(contains('37.618423')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('HTTP')));
      expect(text, isNot(contains('token')));
    });
  });
}

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

Memory memory({
  required String id,
  String storyId = 'private-story-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: 'author-id',
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}
