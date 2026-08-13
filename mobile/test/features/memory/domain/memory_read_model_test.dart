import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

void main() {
  group('MemoryReadModel', () {
    test('shouldWrapDomainMemoryAndOptionalPreview', () {
      final preview = previewPhoto();
      final readModel = MemoryReadModel(memory: memoryA, previewPhoto: preview);

      expect(readModel.memory, same(memoryA));
      expect(readModel.previewPhoto, same(preview));
      expect(readModel.hasPreviewPhoto, isTrue);
    });

    test('shouldCreateFromMemoryWithoutPreview', () {
      final readModel = MemoryReadModel.fromMemory(memoryA);

      expect(readModel.memory, same(memoryA));
      expect(readModel.previewPhoto, isNull);
      expect(readModel.hasPreviewPhoto, isFalse);
    });

    test('shouldPreservePreviewForMemoryMutation', () {
      final preview = previewPhoto();
      final updated = memory(id: memoryA.id, title: 'Updated');
      final readModel = MemoryReadModel(
        memory: memoryA,
        previewPhoto: preview,
      ).withMemoryMutation(updated);

      expect(readModel.memory, same(updated));
      expect(readModel.previewPhoto, same(preview));
    });

    test('shouldRejectMutationForDifferentMemory', () {
      final readModel = MemoryReadModel(memory: memoryA);

      expect(
        () => readModel.withMemoryMutation(memory(id: 'memory-b')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldCompareByValue', () {
      final first = MemoryReadModel(
        memory: memoryA,
        previewPhoto: previewPhoto(),
      );
      final second = MemoryReadModel(
        memory: memoryA,
        previewPhoto: previewPhoto(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final readModel = MemoryReadModel(
        memory: memory(
          id: 'private-memory-id',
          title: 'Private title',
          description: 'Private description',
        ),
        previewPhoto: previewPhoto(mediaId: 'private-media-id'),
      );

      final text = readModel.toString();

      expect(text, 'MemoryReadModel(hasPreviewPhoto: true)');
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('/api/v1/media')));
    });
  });
}

Memory memory({
  String id = 'memory-a',
  String title = 'First picnic',
  String? description = 'Near the river',
}) {
  return Memory(
    id: id,
    storyId: 'story-id',
    createdBy: 'author-id',
    title: title,
    description: description,
    placeName: 'Riverside Park',
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

MemoryPhotoPreview previewPhoto({
  String mediaId = 'media-id',
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

final Memory memoryA = memory();
