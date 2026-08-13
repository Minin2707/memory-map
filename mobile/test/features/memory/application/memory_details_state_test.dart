import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_details_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

void main() {
  group('MemoryDetailsState loaded', () {
    test('shouldExposeLoadedMemoryWithoutFailures', () {
      final state = MemoryDetailsState.loaded(memory: memoryA);

      expect(state.memory, same(memoryA));
      expect(state.isRefreshing, isFalse);
      expect(state.loadFailure, isNull);
      expect(state.refreshFailure, isNull);
      expect(state.hasMemory, isTrue);
      expect(state.isLoaded, isTrue);
      expect(state.hasLoadFailure, isFalse);
    });

    test('shouldSupportRefreshingAndRefreshFailureFlags', () {
      final state = MemoryDetailsState.loaded(
        memory: memoryA,
        isRefreshing: true,
        refreshFailure: const MemoryRequestTimedOut(),
      );

      expect(state.memory, same(memoryA));
      expect(state.isRefreshing, isTrue);
      expect(state.refreshFailure, const MemoryRequestTimedOut());
      expect(state.isLoaded, isTrue);
    });
  });

  group('MemoryDetailsState failures', () {
    test('shouldExposeLoadFailureWithoutMemory', () {
      final state = MemoryDetailsState.loadFailure(const MemoryNotFound());

      expect(state.memory, isNull);
      expect(state.isRefreshing, isFalse);
      expect(state.loadFailure, const MemoryNotFound());
      expect(state.refreshFailure, isNull);
      expect(state.hasMemory, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.hasLoadFailure, isTrue);
    });
  });

  group('MemoryDetailsState copyWith', () {
    test('shouldReplaceMemoryAndFlags', () {
      final state = MemoryDetailsState.loaded(
        memory: memoryA,
        isRefreshing: true,
        refreshFailure: const MemoryNetworkUnavailable(),
      );

      final copied = state.copyWith(
        memory: memoryB,
        isRefreshing: false,
        clearRefreshFailure: true,
      );

      expect(copied.memory, same(memoryB));
      expect(copied.isRefreshing, isFalse);
      expect(copied.refreshFailure, isNull);
    });

    test('shouldPreservePreviewWhenReplacingMemoryOnly', () {
      final preview = previewPhoto(mediaId: 'media-a');
      final state = MemoryDetailsState.loaded(
        memory: memoryA,
        previewPhoto: preview,
      );

      final copied = state.copyWith(memory: memoryB);

      expect(copied.memory, same(memoryB));
      expect(copied.previewPhoto, same(preview));
    });

    test('shouldClearPreviewWhenReplacingAuthoritativeReadModelWithNull', () {
      final state = MemoryDetailsState.loaded(
        memory: memoryA,
        previewPhoto: previewPhoto(mediaId: 'media-a'),
      );

      final copied = state.copyWith(
        readModel: MemoryReadModel(memory: memoryB),
      );

      expect(copied.memory, same(memoryB));
      expect(copied.previewPhoto, isNull);
    });

    test('shouldClearLoadFailure', () {
      final state = MemoryDetailsState.loadFailure(const MemoryNotFound());

      final copied = state.copyWith(clearLoadFailure: true);

      expect(copied.loadFailure, isNull);
      expect(copied.hasLoadFailure, isFalse);
    });
  });

  group('MemoryDetailsState equality', () {
    test('shouldUseValueEqualityAndHashCode', () {
      final first = MemoryDetailsState.loaded(
        memory: memoryA,
        refreshFailure: const MemoryRequestTimedOut(),
      );
      final second = MemoryDetailsState.loaded(
        memory: memoryA,
        refreshFailure: const MemoryRequestTimedOut(),
      );
      final different = MemoryDetailsState.loaded(memory: memoryB);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });
  });

  group('MemoryDetailsState security', () {
    test('shouldHaveSafeToString', () {
      final state = MemoryDetailsState.loaded(
        memory: memory(
          id: 'private-memory-id',
          storyId: 'private-story-id',
          createdBy: 'private-user-id',
          title: 'Private title',
          description: 'Private description',
          placeName: 'Private place',
        ),
        isRefreshing: true,
        refreshFailure: const MemoryServerFailure(),
      );

      final text = state.toString();

      expect(text, contains('hasMemory: true'));
      expect(text, contains('isRefreshing: true'));
      expect(text, contains('hasLoadFailure: false'));
      expect(text, contains('hasRefreshFailure: true'));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('private-user-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(text, isNot(contains('2026-08-09')));
      expect(text, isNot(contains('createdBy')));
      expect(text, isNot(contains('createdAt')));
      expect(text, isNot(contains('updatedAt')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('HTTP')));
      expect(text, isNot(contains('token')));
    });
  });
}

Memory memory({
  String id = 'memory-id',
  String storyId = 'story-id',
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 41.715123, longitude: 44.827456),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

final Memory memoryA = memory(id: 'memory-a', title: 'A');
final Memory memoryB = memory(id: 'memory-b', title: 'B');

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}
