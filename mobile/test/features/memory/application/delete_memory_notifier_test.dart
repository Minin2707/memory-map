import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/delete_memory_notifier.dart';
import 'package:memory_map/features/memory/application/delete_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('DeleteMemoryNotifier startup', () {
    test('shouldStartIdleWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        deleteMemoryProvider(memoryA.id).future,
      );

      expect(state, const DeleteMemoryState());
      expect(repository.deleteMemoryCalls, 0);
      expect(repository.getMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
    });
  });

  group('DeleteMemoryNotifier deleteMemory', () {
    test('shouldForwardExactInputAndReturnSuccess', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);

      expect(success, isTrue);
      expect(repository.deleteMemoryCalls, 1);
      expect(
        repository.receivedDeleteInput,
        DeleteMemoryInput(memoryId: memoryA.id),
      );
      expect(readDeleteState(container, memoryA.id), const DeleteMemoryState());
      expect(repository.getMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
    });

    test('shouldExposeDeletingWhileRepositoryCallIsPending', () async {
      final completer = Completer<void>();
      final repository = FakeMemoryRepository()..deleteCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final delete = container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);
      await pumpEventQueue();

      expect(readDeleteState(container, memoryA.id).isDeleting, isTrue);
      expect(readDeleteState(container, memoryA.id).deleteFailure, isNull);

      completer.complete();
      expect(await delete, isTrue);
      expect(readDeleteState(container, memoryA.id).isDeleting, isFalse);
    });

    test('shouldIgnoreDuplicateDeleteWhileDeleting', () async {
      final completer = Completer<void>();
      final repository = FakeMemoryRepository()..deleteCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMemoryProvider(memoryA.id).future);
      final notifier = container.read(deleteMemoryProvider(memoryA.id).notifier);

      final firstDelete = notifier.deleteMemory(memoryA);
      await pumpEventQueue();
      final secondResult = await notifier.deleteMemory(memoryA);

      expect(secondResult, isFalse);
      expect(repository.deleteMemoryCalls, 1);
      expect(readDeleteState(container, memoryA.id).isDeleting, isTrue);

      completer.complete();
      await firstDelete;
    });

    test('shouldRejectMismatchedMemoryWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryB);

      expect(success, isFalse);
      expect(repository.deleteMemoryCalls, 0);
      expect(
        readDeleteState(container, memoryA.id).deleteFailure,
        const MemoryValidationFailure(),
      );
    });

    test('shouldExposeKnownFailureAndSkipStoryMemoriesSync', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB]
        ..deleteFailure = const MemoryApplicationException(
          MemoryDeletionUnavailable(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);

      expect(success, isFalse);
      expect(readStoryMemories(container), <Memory>[memoryA, memoryB]);
      expect(
        readDeleteState(container, memoryA.id).deleteFailure,
        const MemoryDeletionUnavailable(),
      );
      expect(repository.getMemoriesCalls, 1);
    });

    test('shouldExposeUnexpectedFailureAsAsyncErrorAndSkipSync', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB]
        ..deleteFailure = const UnexpectedMemoryException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);

      final value = container.read(deleteMemoryProvider(memoryA.id));
      expect(success, isFalse);
      expect(value, isA<AsyncError<DeleteMemoryState>>());
      expect(value.error, isA<UnexpectedMemoryException>());
      expect(readStoryMemories(container), <Memory>[memoryA, memoryB]);
    });

    test('shouldClearOldFailureBeforeRetryAndReturnSuccess', () async {
      final completer = Completer<void>();
      final repository = FakeMemoryRepository()
        ..deleteFailure = const MemoryApplicationException(
          MemoryNetworkUnavailable(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMemoryProvider(memoryA.id).future);
      final notifier = container.read(deleteMemoryProvider(memoryA.id).notifier);
      await notifier.deleteMemory(memoryA);

      repository
        ..deleteFailure = null
        ..deleteCompleter = completer;
      final retry = notifier.deleteMemory(memoryA);
      await pumpEventQueue();

      expect(readDeleteState(container, memoryA.id).deleteFailure, isNull);
      expect(readDeleteState(container, memoryA.id).isDeleting, isTrue);

      completer.complete();
      expect(await retry, isTrue);
      expect(readDeleteState(container, memoryA.id), const DeleteMemoryState());
    });
  });

  group('DeleteMemoryNotifier StoryMemories sync', () {
    test('shouldRemoveMemoryFromLoadedStoryMemoriesAfterBackendSuccess',
        () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);

      expect(success, isTrue);
      expect(readStoryMemories(container), <Memory>[memoryB]);
      expect(repository.operations, <String>['getMemories', 'deleteMemory']);
    });

    test('shouldNotOptimisticallyRemoveWhileDeleteIsPending', () async {
      final completer = Completer<void>();
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB]
        ..deleteCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final delete = container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);
      await pumpEventQueue();

      expect(readStoryMemories(container), <Memory>[memoryA, memoryB]);

      completer.complete();
      await delete;

      expect(readStoryMemories(container), <Memory>[memoryB]);
    });

    test('shouldNotForceLoadStoryMemoriesWhenListProviderDoesNotExist',
        () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);

      expect(success, isTrue);
      expect(repository.operations, <String>['deleteMemory']);
      expect(repository.getMemoriesCalls, 0);
    });

    test('shouldNotInvalidateOrReloadLoadedMemoryDetailsAfterDelete', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      await container.read(deleteMemoryProvider(memoryA.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);

      expect(success, isTrue);
      expect(
        container.read(memoryDetailsProvider(memoryA.id)).asData!.value.memory,
        same(memoryA),
      );
      expect(repository.operations, <String>['getMemory', 'deleteMemory']);
      expect(repository.getMemoryCalls, 1);
    });
  });

  group('DeleteMemoryNotifier provider lifecycle', () {
    test('shouldKeepIndependentStatePerMemoryId', () async {
      final repository = FakeMemoryRepository()
        ..deleteFailure = const MemoryApplicationException(
          MemoryRequestTimedOut(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      container.listen(
        deleteMemoryProvider(memoryB.id),
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(deleteMemoryProvider(memoryA.id).future);
      await container.read(deleteMemoryProvider(memoryB.id).future);

      await container
          .read(deleteMemoryProvider(memoryA.id).notifier)
          .deleteMemory(memoryA);

      expect(
        readDeleteState(container, memoryA.id).deleteFailure,
        const MemoryRequestTimedOut(),
      );
      expect(readDeleteState(container, memoryB.id), const DeleteMemoryState());
    });
  });
}

ProviderContainer createContainer(FakeMemoryRepository repository) {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.listen(
    deleteMemoryProvider(memoryA.id),
    (_, __) {},
    fireImmediately: true,
  );
  return container;
}

DeleteMemoryState readDeleteState(
  ProviderContainer container,
  String memoryId,
) {
  return container.read(deleteMemoryProvider(memoryId)).asData!.value;
}

List<Memory> readStoryMemories(ProviderContainer container) {
  return container
      .read(storyMemoriesProvider(defaultStoryId))
      .asData!
      .value
      .memories;
}

Memory memory({
  String id = '00000000-0000-0000-0000-000000000001',
  String storyId = defaultStoryId,
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
  int day = 9,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 41.715123, longitude: 44.827456),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultStoryId = 'story-id';
final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'A',
);
final Memory memoryB = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'B',
  day: 20,
);

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<void>? deleteCompleter;
  DeleteMemoryInput? receivedDeleteInput;
  List<Memory> memoriesResult = <Memory>[];
  Memory memoryResult = memoryA;
  Object? deleteFailure;
  final List<String> operations = <String>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    operations.add('getMemories');

    return memoriesResult.map(MemoryReadModel.fromMemory).toList();
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    operations.add('getMemory');

    return MemoryReadModel.fromMemory(memoryResult);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    operations.add('createMemory');

    return memoryResult;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    operations.add('updateMemory');

    return memoryResult;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
    receivedDeleteInput = input;
    operations.add('deleteMemory');

    final completer = deleteCompleter;
    if (completer != null) {
      deleteCompleter = null;
      return completer.future;
    }

    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}
