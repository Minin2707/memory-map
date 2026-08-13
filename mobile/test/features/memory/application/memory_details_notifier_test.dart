import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/memory_details_state.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('MemoryDetailsNotifier startup', () {
    test('shouldStartWithAsyncLoading', () async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..getMemoryCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final future = container.read(memoryDetailsProvider(memoryA.id).future);

      expect(
        container.read(memoryDetailsProvider(memoryA.id)),
        isA<AsyncLoading<MemoryDetailsState>>(),
      );

      completer.complete(memoryA);
      await future;
    });

    test('shouldLoadMemoryFromRepository', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        memoryDetailsProvider(memoryA.id).future,
      );

      expect(state.memory, same(memoryA));
      expect(state.isLoaded, isTrue);
      expect(repository.receivedMemoryIds, <String>[memoryA.id]);
      expect(repository.getMemoryCalls, 1);
    });

    test('shouldRejectBlankMemoryIdWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(memoryDetailsProvider('   ').future);

      expect(state.loadFailure, const MemoryNotFound());
      expect(repository.getMemoryCalls, 0);
    });

    test('shouldExposeKnownLoadFailureAsState', () async {
      final repository = FakeMemoryRepository()
        ..getMemoryFailures.add(
          const MemoryApplicationException(MemoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        memoryDetailsProvider(memoryA.id).future,
      );

      expect(state.memory, isNull);
      expect(state.loadFailure, const MemoryUnauthorized());
    });

    test('shouldExposeUnexpectedLoadFailureAsAsyncError', () async {
      final repository = FakeMemoryRepository()
        ..getMemoryFailures.add(const UnexpectedMemoryException());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<MemoryDetailsState>>();
      final subscription = container.listen(
        memoryDetailsProvider(memoryA.id),
        (previous, next) {
          if (next.hasError && !errorState.isCompleted) {
            errorState.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final state = await errorState.future;

      expect(state.hasError, isTrue);
      expect(state.error, isA<UnexpectedMemoryException>());
    });
  });

  group('MemoryDetailsNotifier retry', () {
    test('shouldRetryAfterKnownLoadFailure', () async {
      final repository = FakeMemoryRepository()
        ..getMemoryFailures.add(
          const MemoryApplicationException(MemoryNetworkUnavailable()),
        )
        ..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);

      await container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .retryLoad();

      expect(repository.getMemoryCalls, 2);
      expect(readState(container, memoryA.id).memory, same(memoryA));
      expect(readState(container, memoryA.id).loadFailure, isNull);
    });

    test('shouldShowLoadingDuringRetryAndIgnoreDuplicateRetry', () async {
      final retryCompleter = Completer<Memory>();
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.getMemoryCompleter = retryCompleter;

      final notifier = container.read(memoryDetailsProvider(memoryA.id).notifier);
      final retry = notifier.retryLoad();
      await pumpEventQueue();
      await notifier.retryLoad();

      expect(
        container.read(memoryDetailsProvider(memoryA.id)),
        isA<AsyncLoading<MemoryDetailsState>>(),
      );
      expect(repository.getMemoryCalls, 2);

      retryCompleter.complete(memoryA);
      await retry;
    });
  });

  group('MemoryDetailsNotifier refresh', () {
    test('shouldPreserveMemoryWhileRefreshing', () async {
      final refreshCompleter = Completer<Memory>();
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.getMemoryCompleter = refreshCompleter;

      final refresh = container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .refreshMemory();
      await pumpEventQueue();

      final state = readState(container, memoryA.id);
      expect(state.memory, same(memoryA));
      expect(state.isRefreshing, isTrue);

      refreshCompleter.complete(memoryB);
      await refresh;
    });

    test('shouldReplaceMemoryWithAuthoritativeRefreshResult', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.memoryResult = memoryB;

      await container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .refreshMemory();

      final state = readState(container, memoryA.id);
      expect(state.memory, same(memoryB));
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, isNull);
    });

    test('shouldKeepMemoryAndExposeRefreshFailureForKnownFailure', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.getMemoryFailures.add(
        const MemoryApplicationException(MemoryRequestTimedOut()),
      );

      await container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .refreshMemory();

      final state = readState(container, memoryA.id);
      expect(state.memory, same(memoryA));
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, const MemoryRequestTimedOut());
    });

    test('shouldExposeUnexpectedRefreshFailureAsAsyncError', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.getMemoryFailures.add(const UnexpectedMemoryException());

      await container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .refreshMemory();

      expect(
        container.read(memoryDetailsProvider(memoryA.id)),
        isA<AsyncError<MemoryDetailsState>>(),
      );
    });

    test('shouldIgnoreDuplicateRefreshAndRefreshAfterLoadFailure', () async {
      final refreshCompleter = Completer<Memory>();
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.getMemoryCompleter = refreshCompleter;

      final notifier = container.read(memoryDetailsProvider(memoryA.id).notifier);
      final firstRefresh = notifier.refreshMemory();
      await pumpEventQueue();
      await notifier.refreshMemory();

      expect(repository.getMemoryCalls, 2);

      refreshCompleter.complete(memoryA);
      await firstRefresh;

      final failedRepository = FakeMemoryRepository()
        ..getMemoryFailures.add(
          const MemoryApplicationException(MemoryNotFound()),
        );
      final failedContainer = createContainer(failedRepository);
      addTearDown(failedContainer.dispose);
      await failedContainer.read(memoryDetailsProvider(memoryB.id).future);

      await failedContainer
          .read(memoryDetailsProvider(memoryB.id).notifier)
          .refreshMemory();

      expect(failedRepository.getMemoryCalls, 1);
    });
  });

  group('MemoryDetailsNotifier applyUpdatedMemory', () {
    test('shouldReplaceLoadedMemoryAndClearRefreshFailure', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.getMemoryFailures.add(
        const MemoryApplicationException(MemoryNetworkUnavailable()),
      );
      await container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .refreshMemory();

      final updated = memory(id: memoryA.id, title: 'Updated title');
      container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .applyUpdatedMemory(updated);

      final state = readState(container, memoryA.id);
      expect(state.memory, same(updated));
      expect(state.refreshFailure, isNull);
      expect(repository.operations, <String>['getMemory', 'getMemory']);
    });

    test('shouldIgnoreMismatchedMemoryId', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);

      container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .applyUpdatedMemory(memoryB);

      expect(readState(container, memoryA.id).memory, same(memoryA));
      expect(repository.operations, <String>['getMemory']);
    });

    test('shouldBeStableWhenRepeatedWithSameMemory', () async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      final notifier = container.read(memoryDetailsProvider(memoryA.id).notifier);

      notifier.applyUpdatedMemory(memoryA);
      notifier.applyUpdatedMemory(memoryA);

      expect(readState(container, memoryA.id).memory, same(memoryA));
      expect(repository.operations, <String>['getMemory']);
    });

    test('shouldIgnoreReplacementAfterLoadFailure', () async {
      final repository = FakeMemoryRepository()
        ..getMemoryFailures.add(
          const MemoryApplicationException(MemoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);

      container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .applyUpdatedMemory(memoryA);

      final state = readState(container, memoryA.id);
      expect(state.memory, isNull);
      expect(state.loadFailure, const MemoryUnauthorized());
    });

    test('shouldIgnoreReplacementDuringInitialLoading', () async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..getMemoryCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final load = container.read(memoryDetailsProvider(memoryA.id).future);
      await pumpEventQueue();
      container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .applyUpdatedMemory(memoryB);

      completer.complete(memoryA);
      await load;

      expect(readState(container, memoryA.id).memory, same(memoryA));
    });

    test('shouldAllowLocalReplacementDuringRefreshButRefreshResultWins',
        () async {
      final refreshCompleter = Completer<Memory>();
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      repository.getMemoryCompleter = refreshCompleter;
      final notifier = container.read(memoryDetailsProvider(memoryA.id).notifier);
      final locallyUpdated = memory(id: memoryA.id, title: 'Local title');
      final serverUpdated = memory(id: memoryA.id, title: 'Server title');

      final refresh = notifier.refreshMemory();
      await pumpEventQueue();
      notifier.applyUpdatedMemory(locallyUpdated);

      expect(readState(container, memoryA.id).memory, same(locallyUpdated));

      refreshCompleter.complete(serverUpdated);
      await refresh;

      expect(readState(container, memoryA.id).memory, same(serverUpdated));
    });

    test('shouldPreservePreviewWhenApplyingMutationMemory', () async {
      final preview = previewPhoto(mediaId: 'media-a');
      final repository = FakeMemoryRepository()
        ..memoryReadModelResult = MemoryReadModel(
          memory: memoryA,
          previewPhoto: preview,
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);

      final updated = memory(id: memoryA.id, title: 'Updated');
      container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .applyUpdatedMemory(updated);

      final state = readState(container, memoryA.id);
      expect(state.memory, same(updated));
      expect(state.previewPhoto, same(preview));
    });

    test('shouldReplacePreviewWhenApplyingAuthoritativeReadModel', () async {
      final oldPreview = previewPhoto(mediaId: 'media-old');
      final newPreview = previewPhoto(mediaId: 'media-new');
      final repository = FakeMemoryRepository()
        ..memoryReadModelResult = MemoryReadModel(
          memory: memoryA,
          previewPhoto: oldPreview,
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);

      final updated = memory(id: memoryA.id, title: 'Updated');
      container.read(memoryDetailsProvider(memoryA.id).notifier)
          .applyAuthoritativeRead(
            MemoryReadModel(memory: updated, previewPhoto: newPreview),
          );

      final state = readState(container, memoryA.id);
      expect(state.memory, same(updated));
      expect(state.previewPhoto, same(newPreview));
    });
  });

  group('MemoryDetailsNotifier provider lifecycle', () {
    test('shouldKeepIndependentStatePerMemoryId', () async {
      final repository = FakeMemoryRepository()
        ..memoryResults.add(memoryA)
        ..memoryResults.add(memoryB);
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final first = await container.read(
        memoryDetailsProvider(memoryA.id).future,
      );
      final second = await container.read(
        memoryDetailsProvider(memoryB.id).future,
      );

      container
          .read(memoryDetailsProvider(memoryA.id).notifier)
          .applyUpdatedMemory(memory(id: memoryA.id, title: 'Updated A'));

      expect(first.memory, same(memoryA));
      expect(second.memory, same(memoryB));
      expect(readState(container, memoryA.id).memory!.title, 'Updated A');
      expect(readState(container, memoryB.id).memory, same(memoryB));
      expect(repository.receivedMemoryIds, <String>[memoryA.id, memoryB.id]);
    });
  });

  group('MemoryDetailsNotifier security', () {
    test('shouldNotExposeMemoryDetailsThroughNotifierStateToString', () async {
      final repository = FakeMemoryRepository()
        ..memoryResult = memory(
          id: 'private-memory-id',
          storyId: 'private-story-id',
          createdBy: 'private-user-id',
          title: 'Private title',
          description: 'Private description',
          placeName: 'Private place',
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider('private-memory-id').future);

      final text = container
          .read(memoryDetailsProvider('private-memory-id'))
          .toString();

      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('private-user-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('HTTP')));
      expect(text, isNot(contains('token')));
    });
  });
}

ProviderContainer createContainer(FakeMemoryRepository repository) {
  return ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

MemoryDetailsState readState(ProviderContainer container, String memoryId) {
  return container.read(memoryDetailsProvider(memoryId)).asData!.value;
}

Memory memory({
  required String id,
  String storyId = 'story-id',
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
  int day = 9,
  int createdHour = 10,
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
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'A',
);
final Memory memoryB = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'B',
);

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<Memory>? getMemoryCompleter;
  Memory memoryResult = memoryA;
  MemoryReadModel? memoryReadModelResult;
  final List<Memory> memoryResults = <Memory>[];
  final List<Object> getMemoryFailures = <Object>[];
  final List<String> receivedMemoryIds = <String>[];
  final List<String> operations = <String>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    operations.add('getMemories');

    return <MemoryReadModel>[];
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    receivedMemoryIds.add(memoryId);
    operations.add('getMemory');

    final configuredCompleter = getMemoryCompleter;
    if (configuredCompleter != null) {
      getMemoryCompleter = null;
      return configuredCompleter.future.then(MemoryReadModel.fromMemory);
    }

    if (getMemoryFailures.isNotEmpty) {
      throw getMemoryFailures.removeAt(0);
    }

    if (memoryResults.isNotEmpty) {
      return MemoryReadModel.fromMemory(memoryResults.removeAt(0));
    }

    final configuredReadModel = memoryReadModelResult;
    if (configuredReadModel != null) {
      return configuredReadModel;
    }

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
    operations.add('deleteMemory');
  }
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}
