import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('MemoryRepository', () {
    test('shouldExposeGetMemoriesContract', () async {
      final repository = FakeMemoryRepository();

      final memories = await repository.getMemories('story-id');

      expect(repository.receivedGetMemoriesStoryId, 'story-id');
      expect(memories, [MemoryReadModel.fromMemory(createTestMemory())]);
    });

    test('shouldExposeGetMemoryContract', () async {
      final repository = FakeMemoryRepository();

      final memory = await repository.getMemory('memory-id');

      expect(repository.receivedGetMemoryId, 'memory-id');
      expect(memory, MemoryReadModel.fromMemory(createTestMemory()));
    });

    test('shouldExposeCreateMemoryContract', () async {
      final repository = FakeMemoryRepository();
      final input = createInput();

      final memory = await repository.createMemory(input);

      expect(repository.receivedCreateInput, input);
      expect(memory, createTestMemory());
    });

    test('shouldExposeUpdateMemoryContract', () async {
      final repository = FakeMemoryRepository();
      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        title: const MemoryUpdateField<String>.provided('Updated title'),
      );

      final memory = await repository.updateMemory(input);

      expect(repository.receivedUpdateInput, input);
      expect(memory, createTestMemory(title: 'Updated title'));
    });

    test('shouldExposeDeleteMemoryContract', () async {
      final repository = FakeMemoryRepository();
      final input = DeleteMemoryInput(memoryId: 'memory-id');

      await repository.deleteMemory(input);

      expect(repository.receivedDeleteInput, input);
    });
  });
}

final class FakeMemoryRepository implements MemoryRepository {
  String? receivedGetMemoriesStoryId;
  String? receivedGetMemoryId;
  CreateMemoryInput? receivedCreateInput;
  UpdateMemoryInput? receivedUpdateInput;
  DeleteMemoryInput? receivedDeleteInput;

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    receivedGetMemoriesStoryId = storyId;

    return [MemoryReadModel.fromMemory(createTestMemory())];
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    receivedGetMemoryId = memoryId;

    return MemoryReadModel.fromMemory(createTestMemory());
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    receivedCreateInput = input;

    return createTestMemory();
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    receivedUpdateInput = input;

    return createTestMemory(
      title: input.title.value ?? 'First day in Tbilisi',
    );
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    receivedDeleteInput = input;
  }
}

CreateMemoryInput createInput() {
  return CreateMemoryInput(
    storyId: 'story-id',
    title: 'First day in Tbilisi',
    description: 'Old city walk',
    placeName: 'Tbilisi',
    location: createLocation(),
    eventDate: createDate(),
  );
}

Memory createTestMemory({
  String title = 'First day in Tbilisi',
}) {
  return Memory(
    id: 'memory-id',
    storyId: 'story-id',
    createdBy: 'author-id',
    title: title,
    description: 'Old city walk',
    placeName: 'Tbilisi',
    location: createLocation(),
    eventDate: createDate(),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

MemoryLocation createLocation() {
  return MemoryLocation(latitude: 41.6938, longitude: 44.8015);
}

MemoryDate createDate() {
  return MemoryDate(year: 2024, month: 5, day: 18);
}


