import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('StoryMemoriesNotifier startup', () {
    test('shouldStartWithAsyncLoading', () async {
      final completer = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()..getCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final future = container.read(storyMemoriesProvider('story-1').future);

      expect(
        container.read(storyMemoriesProvider('story-1')),
        isA<AsyncLoading<StoryMemoriesState>>(),
      );

      completer.complete(<Memory>[memoryA]);
      await future;
    });

    test('shouldLoadMemoriesFromRepository', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyMemoriesProvider('story-1').future,
      );

      expect(state.memories, <Memory>[memoryA, memoryB]);
      expect(repository.receivedStoryIds, <String>['story-1']);
      expect(repository.getMemoriesCalls, 1);
    });

    test('shouldPreserveInitialBackendOrderWithoutSorting', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryC, memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyMemoriesProvider('story-1').future,
      );

      expect(state.memories, <Memory>[memoryC, memoryA, memoryB]);
    });

    test('shouldRepresentEmptyLoadedListWithoutFailure', () async {
      final repository = FakeMemoryRepository()..memoriesResult = <Memory>[];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyMemoriesProvider('story-1').future,
      );

      expect(state.memories, isEmpty);
      expect(state.loadFailure, isNull);
    });

    test('shouldExposeKnownLoadFailureAsState', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyMemoriesProvider('story-1').future,
      );

      expect(state.memories, isEmpty);
      expect(state.loadFailure, const MemoryStoryUnavailable());
    });

    test('shouldExposeUnexpectedLoadFailureAsAsyncError', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(const UnexpectedMemoryException());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<StoryMemoriesState>>();
      final subscription = container.listen(
        storyMemoriesProvider('story-1'),
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

    test('shouldRejectBlankStoryIdWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storyMemoriesProvider('   ').future);

      expect(state.loadFailure, const MemoryValidationFailure());
      expect(repository.getMemoriesCalls, 0);
    });
  });

  group('StoryMemoriesNotifier retry', () {
    test('shouldRetryAfterKnownLoadFailure', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryNetworkUnavailable()),
        )
        ..memoriesResults.add(<Memory>[memoryA]);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .retryLoad();

      expect(repository.getMemoriesCalls, 2);
      expect(readState(container, 'story-1').memories, <Memory>[memoryA]);
      expect(readState(container, 'story-1').loadFailure, isNull);
    });

    test('shouldShowLoadingDuringRetryAndIgnoreDuplicateRetry', () async {
      final retryCompleter = Completer<List<Memory>>();
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.getCompleter = retryCompleter;

      final notifier = container.read(storyMemoriesProvider('story-1').notifier);
      final retry = notifier.retryLoad();
      await pumpEventQueue();
      await notifier.retryLoad();

      expect(
        container.read(storyMemoriesProvider('story-1')),
        isA<AsyncLoading<StoryMemoriesState>>(),
      );
      expect(repository.getMemoriesCalls, 2);

      retryCompleter.complete(<Memory>[memoryA]);
      await retry;
    });
  });

  group('StoryMemoriesNotifier refresh', () {
    test('shouldPreserveMemoriesWhileRefreshing', () async {
      final refreshCompleter = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.getCompleter = refreshCompleter;

      final refresh = container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();
      await pumpEventQueue();

      final state = readState(container, 'story-1');
      expect(state.memories, <Memory>[memoryA]);
      expect(state.isRefreshing, isTrue);

      refreshCompleter.complete(<Memory>[memoryB]);
      await refresh;
    });

    test('shouldReplaceMemoriesWithAuthoritativeRefreshOrder', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.memoriesResult = <Memory>[memoryB, memoryC, memoryA];

      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();

      final state = readState(container, 'story-1');
      expect(state.memories, <Memory>[memoryB, memoryC, memoryA]);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, isNull);
    });

    test('shouldKeepMemoriesAndExposeRefreshFailureForKnownFailure', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.getFailures.add(
        const MemoryApplicationException(MemoryRequestTimedOut()),
      );

      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();

      final state = readState(container, 'story-1');
      expect(state.memories, <Memory>[memoryA]);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, const MemoryRequestTimedOut());
    });

    test('shouldExposeUnexpectedRefreshFailureAsAsyncError', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.getFailures.add(const UnexpectedMemoryException());

      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();

      expect(
        container.read(storyMemoriesProvider('story-1')),
        isA<AsyncError<StoryMemoriesState>>(),
      );
    });

    test('shouldIgnoreDuplicateRefreshAndRefreshAfterLoadFailure', () async {
      final refreshCompleter = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.getCompleter = refreshCompleter;

      final notifier = container.read(storyMemoriesProvider('story-1').notifier);
      final firstRefresh = notifier.refreshMemories();
      await pumpEventQueue();
      await notifier.refreshMemories();

      expect(repository.getMemoriesCalls, 2);

      refreshCompleter.complete(<Memory>[memoryA]);
      await firstRefresh;

      final failedRepository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        );
      final failedContainer = createContainer(failedRepository);
      addTearDown(failedContainer.dispose);
      await failedContainer.read(storyMemoriesProvider('story-2').future);

      await failedContainer
          .read(storyMemoriesProvider('story-2').notifier)
          .refreshMemories();

      expect(failedRepository.getMemoriesCalls, 1);
    });
  });

  group('StoryMemoriesNotifier upsertMemory', () {
    test('shouldInsertMissingMemoryByCanonicalEventDateOrder', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryC];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      final originalMemories = readState(container, 'story-1').memories;

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryB);

      final memories = readState(container, 'story-1').memories;
      expect(memories, <Memory>[memoryA, memoryB, memoryC]);
      expect(memories[1], same(memoryB));
      expect(originalMemories, <Memory>[memoryA, memoryC]);
      expect(identical(memories, originalMemories), isFalse);
      expect(
        () => memories.add(memory(id: '00000000-0000-0000-0000-000000000099')),
        throwsA(isA<UnsupportedError>()),
      );
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldSortByCreatedAtWhenEventDateMatches', () async {
      final early = memory(
        id: '00000000-0000-0000-0000-000000000011',
        day: 9,
        createdHour: 10,
      );
      final late = memory(
        id: '00000000-0000-0000-0000-000000000013',
        day: 9,
        createdHour: 12,
      );
      final middle = memory(
        id: '00000000-0000-0000-0000-000000000012',
        day: 9,
        createdHour: 11,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[early, late];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(middle);

      expect(readState(container, 'story-1').memories, <Memory>[
        early,
        middle,
        late,
      ]);
    });

    test('shouldSortByIdWhenEventDateAndCreatedAtMatch', () async {
      final last = memory(id: '00000000-0000-0000-0000-00000000000c');
      final first = memory(id: '00000000-0000-0000-0000-00000000000a');
      final middle = memory(id: '00000000-0000-0000-0000-00000000000b');
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[last, first];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(middle);

      expect(readState(container, 'story-1').memories, <Memory>[
        first,
        middle,
        last,
      ]);
    });

    test('shouldReorderUpdatedMemoryWhenSortKeysChange', () async {
      final updatedC = memory(
        id: memoryC.id,
        title: 'Updated C',
        day: 1,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB, memoryC];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(updatedC);

      final memories = readState(container, 'story-1').memories;
      expect(memories, <Memory>[updatedC, memoryA, memoryB]);
      expect(memories.where((memory) => memory.id == memoryC.id), <Memory>[
        updatedC,
      ]);
      expect(memories.first, same(updatedC));
    });

    test('shouldReplaceExistingMemoryWithoutReconstructingOtherMemories',
        () async {
      final updatedB = memory(id: memoryB.id, title: 'Server title', day: 15);
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB, memoryC];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(updatedB);

      final memories = readState(container, 'story-1').memories;
      expect(memories, <Memory>[memoryA, updatedB, memoryC]);
      expect(memories.first, same(memoryA));
      expect(memories[1], same(updatedB));
      expect(memories.last, same(memoryC));
    });

    test('shouldAppendOnceThenReplaceRepeatedMemory', () async {
      final created = memory(id: '00000000-0000-0000-0000-000000000099');
      final updated = memory(
        id: created.id,
        title: 'Updated authoritative title',
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      final notifier = container.read(storyMemoriesProvider('story-1').notifier);

      notifier.upsertMemory(created);
      notifier.upsertMemory(updated);

      final memories = readState(container, 'story-1').memories;
      expect(
        memories.where((memory) => memory.id == created.id),
        <Memory>[updated],
      );
      expect(memories.length, 2);
    });

    test('shouldRemoveAccidentalDuplicateMatchesBeforeUpsert', () async {
      final duplicateB = memory(
        id: memoryB.id,
        title: 'Duplicate B',
        day: 30,
      );
      final authoritativeB = memory(
        id: memoryB.id,
        title: 'Authoritative B',
        day: 15,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB, duplicateB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(authoritativeB);

      expect(
        readState(container, 'story-1')
            .memories
            .where((memory) => memory.id == memoryB.id),
        <Memory>[authoritativeB],
      );
    });

    test('shouldInsertIntoSuccessfullyLoadedEmptyList', () async {
      final repository = FakeMemoryRepository()..memoriesResult = <Memory>[];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryA);

      expect(readState(container, 'story-1').memories, <Memory>[memoryA]);
    });

    test('shouldIgnoreMismatchedStoryMemory', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container.read(storyMemoriesProvider('story-1').notifier).upsertMemory(
            memory(
              id: '00000000-0000-0000-0000-000000000099',
              storyId: 'story-2',
            ),
          );

      expect(readState(container, 'story-1').memories, <Memory>[memoryA]);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldIgnoreUpsertWhenInitialLoadFailed', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryA);

      expect(readState(container, 'story-1').memories, isEmpty);
      expect(
        readState(container, 'story-1').loadFailure,
        const MemoryUnauthorized(),
      );
    });

    test('shouldIgnoreUpsertDuringInitialLoading', () async {
      final completer = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()..getCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final load = container.read(storyMemoriesProvider('story-1').future);
      await pumpEventQueue();
      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryA);

      completer.complete(<Memory>[]);
      await load;

      expect(readState(container, 'story-1').memories, isEmpty);
    });

    test('shouldIgnoreUpsertAfterUnexpectedAsyncError', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(const UnexpectedMemoryException());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final errorState = Completer<void>();
      final subscription = container.listen(
        storyMemoriesProvider('story-1'),
        (previous, next) {
          if (next.hasError && !errorState.isCompleted) {
            errorState.complete();
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await errorState.future;

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryA);

      expect(container.read(storyMemoriesProvider('story-1')).hasError, isTrue);
    });

    test('shouldRetainRefreshFailureWhenApplyingLocalUpsert', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.getFailures.add(
        const MemoryApplicationException(MemoryNetworkUnavailable()),
      );
      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryB);

      final state = readState(container, 'story-1');
      expect(state.memories, <Memory>[memoryA, memoryB]);
      expect(state.refreshFailure, const MemoryNetworkUnavailable());
    });

    test('shouldAllowLocalUpsertDuringRefreshButRefreshResultWins', () async {
      final refreshCompleter = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      repository.getCompleter = refreshCompleter;
      final notifier = container.read(storyMemoriesProvider('story-1').notifier);

      final refresh = notifier.refreshMemories();
      await pumpEventQueue();
      notifier.upsertMemory(memoryB);

      expect(readState(container, 'story-1').memories, <Memory>[
        memoryA,
        memoryB,
      ]);

      refreshCompleter.complete(<Memory>[memoryC]);
      await refresh;

      expect(readState(container, 'story-1').memories, <Memory>[memoryC]);
    });
  });

  group('StoryMemoriesNotifier removeMemoryById', () {
    test('shouldRemoveMatchingMemoryWithoutChangingRemainingOrder', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB, memoryC];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      final originalMemories = readState(container, 'story-1').memories;

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .removeMemoryById(memoryB.id);

      final memories = readState(container, 'story-1').memories;
      expect(memories, <Memory>[memoryA, memoryC]);
      expect(memories.first, same(memoryA));
      expect(memories.last, same(memoryC));
      expect(originalMemories, <Memory>[memoryA, memoryB, memoryC]);
      expect(identical(memories, originalMemories), isFalse);
      expect(
        () => memories.add(memory(id: '00000000-0000-0000-0000-000000000099')),
        throwsA(isA<UnsupportedError>()),
      );
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldNoOpWhenMemoryIdIsMissingOrBlank', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      final originalMemories = readState(container, 'story-1').memories;

      final notifier = container.read(storyMemoriesProvider('story-1').notifier);
      notifier.removeMemoryById('missing-memory');
      notifier.removeMemoryById('   ');

      expect(readState(container, 'story-1').memories, originalMemories);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldRemoveAllAccidentalDuplicateMatches', () async {
      final duplicateA = memory(
        id: memoryA.id,
        title: 'Duplicate A',
        day: 30,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB, duplicateA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .removeMemoryById(memoryA.id);

      expect(readState(container, 'story-1').memories, <Memory>[memoryB]);
    });

    test('shouldBeSafeWhenRepeated', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      final notifier = container.read(storyMemoriesProvider('story-1').notifier);

      notifier.removeMemoryById(memoryA.id);
      notifier.removeMemoryById(memoryA.id);

      expect(readState(container, 'story-1').memories, <Memory>[memoryB]);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldIgnoreRemovalWhenInitialLoadFailed', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .removeMemoryById(memoryA.id);

      expect(readState(container, 'story-1').memories, isEmpty);
      expect(
        readState(container, 'story-1').loadFailure,
        const MemoryUnauthorized(),
      );
      expect(repository.operations, <String>['getMemories']);
    });
  });

  group('StoryMemoriesNotifier provider lifecycle', () {
    test('shouldKeepIndependentStatePerStoryId', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResults.add(<Memory>[memoryA])
        ..memoriesResults.add(<Memory>[memoryForStory2]);
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final first = await container.read(
        storyMemoriesProvider('story-1').future,
      );
      final second = await container.read(
        storyMemoriesProvider('story-2').future,
      );

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryB);
      container
          .read(storyMemoriesProvider('story-2').notifier)
          .removeMemoryById(memoryForStory2.id);

      expect(first.memories, <Memory>[memoryA]);
      expect(second.memories, <Memory>[memoryForStory2]);
      expect(readState(container, 'story-1').memories, <Memory>[
        memoryA,
        memoryB,
      ]);
      expect(readState(container, 'story-2').memories, isEmpty);
      expect(repository.receivedStoryIds, <String>['story-1', 'story-2']);
    });
  });

  group('StoryMemoriesNotifier security', () {
    test('shouldNotExposeMemoryDetailsThroughNotifierStateToString', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[
          memory(
            id: 'private-memory-id',
            storyId: 'private-story-id',
            title: 'Private title',
            description: 'Private description',
            placeName: 'Private place',
          ),
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('private-story-id').future);

      final text = container
          .read(storyMemoriesProvider('private-story-id'))
          .toString();

      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('55.751244')));
      expect(text, isNot(contains('37.618423')));
      expect(text, isNot(contains('Dio')));
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

StoryMemoriesState readState(ProviderContainer container, String storyId) {
  return container.read(storyMemoriesProvider(storyId)).asData!.value;
}

Memory memory({
  required String id,
  String storyId = 'story-1',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
  int day = 9,
  int createdHour = 10,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: 'author-id',
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'A',
  day: 10,
);
final Memory memoryB = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'B',
  day: 15,
);
final Memory memoryC = memory(
  id: '00000000-0000-0000-0000-000000000003',
  title: 'C',
  day: 20,
);
final Memory memoryForStory2 = memory(
  id: '00000000-0000-0000-0000-000000000101',
  storyId: 'story-2',
  title: 'Story 2 memory',
);

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<List<Memory>>? getCompleter;
  List<Memory> memoriesResult = <Memory>[];
  final List<List<Memory>> memoriesResults = <List<Memory>>[];
  final List<Object> getFailures = <Object>[];
  final List<String> receivedStoryIds = <String>[];
  final List<String> operations = <String>[];

  @override
  Future<List<Memory>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    receivedStoryIds.add(storyId);
    operations.add('getMemories');

    final configuredCompleter = getCompleter;
    if (configuredCompleter != null) {
      getCompleter = null;
      return configuredCompleter.future;
    }

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    if (memoriesResults.isNotEmpty) {
      return memoriesResults.removeAt(0);
    }

    return memoriesResult;
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    operations.add('getMemory');

    return memoryA;
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    operations.add('createMemory');

    return memoryA;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    operations.add('updateMemory');

    return memoryA;
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
