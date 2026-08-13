import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/presentation/story_map_selected_memory.dart';

void main() {
  group('findSelectedStoryMapMemory', () {
    test('shouldReturnNullWhenSelectionIsNull', () {
      final selected = findSelectedStoryMapMemory(<Memory>[memoryA], null);

      expect(selected, isNull);
    });

    test('shouldReturnExactAuthoritativeMemoryWhenIdExists', () {
      final selected = findSelectedStoryMapMemory(
        <Memory>[memoryA, memoryB],
        memoryB.id,
      );

      expect(selected, same(memoryB));
    });

    test('shouldReturnNullWhenIdIsUnknown', () {
      final selected = findSelectedStoryMapMemory(
        <Memory>[memoryA],
        'unknown-memory',
      );

      expect(selected, isNull);
    });

    test('shouldResolveUpdatedMemoryValueFromCurrentList', () {
      final updatedB = memory(id: memoryB.id, title: 'Updated title');

      final selected = findSelectedStoryMapMemory(
        <Memory>[memoryA, updatedB],
        memoryB.id,
      );

      expect(selected, same(updatedB));
      expect(selected!.title, 'Updated title');
    });
  });

  group('findSelectedStoryMapMemoryReadModel', () {
    test('shouldReturnExactReadModelWithPreviewWhenIdExists', () {
      final preview = previewPhoto(mediaId: 'media-b');
      final readModel = MemoryReadModel(
        memory: memoryB,
        previewPhoto: preview,
      );

      final selected = findSelectedStoryMapMemoryReadModel(
        <MemoryReadModel>[
          MemoryReadModel.fromMemory(memoryA),
          readModel,
        ],
        memoryB.id,
      );

      expect(selected, same(readModel));
      expect(selected!.memory, same(memoryB));
      expect(selected.previewPhoto, same(preview));
    });

    test('shouldReturnNullWhenReadModelSelectionIsMissing', () {
      final selected = findSelectedStoryMapMemoryReadModel(
        <MemoryReadModel>[MemoryReadModel.fromMemory(memoryA)],
        'unknown-memory',
      );

      expect(selected, isNull);
    });
  });
}

Memory memory({
  required String id,
  String title = 'Memory title',
}) {
  return Memory(
    id: id,
    storyId: 'story-id',
    createdBy: 'author-id',
    title: title,
    description: 'Private description',
    placeName: 'Private place',
    location: MemoryLocation(latitude: 41.7151, longitude: 44.8271),
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
