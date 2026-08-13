import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/default_memory_repository.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/data/remote/dio_memory_remote_data_source.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_data_source.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';

void main() {
  group('memoryRepositoryProvider', () {
    test('shouldCreateMemoryRepositoryFromRemoteProvider', () {
      final remote = FakeMemoryRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          memoryRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(memoryRepositoryProvider);

      expect(repository, isA<MemoryRepository>());
      expect(repository, isA<DefaultMemoryRepository>());
      expect(remote.totalCalls, 0);
    });

    test('shouldDelegateThroughProviderCreatedRepository', () async {
      final remote = FakeMemoryRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          memoryRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(memoryRepositoryProvider);

      final memory = await repository.getMemory('memory-id');

      expect(memory.memory, memoryFixture);
      expect(remote.receivedMemoryId, 'memory-id');
      expect(remote.totalCalls, 1);
    });
  });
}

final Memory memoryFixture = Memory(
  id: 'memory-id',
  storyId: 'story-id',
  createdBy: 'author-id',
  title: 'First picnic',
  description: 'Near the river',
  placeName: 'Riverside Park',
  location: MemoryLocation(
    latitude: 55.751244,
    longitude: 37.618423,
  ),
  eventDate: MemoryDate(year: 2026, month: 8, day: 9),
  createdAt: DateTime.utc(2026, 8, 9, 10),
  updatedAt: DateTime.utc(2026, 8, 9, 11),
);

final class FakeMemoryRemoteDataSource implements MemoryRemoteDataSource {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  String? receivedMemoryId;

  int get totalCalls {
    return getMemoriesCalls +
        getMemoryCalls +
        createMemoryCalls +
        updateMemoryCalls +
        deleteMemoryCalls;
  }

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;

    return <MemoryReadModel>[MemoryReadModel.fromMemory(memoryFixture)];
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    receivedMemoryId = memoryId;

    return MemoryReadModel.fromMemory(memoryFixture);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;

    return memoryFixture;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;

    return memoryFixture;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
  }
}

