import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_map_notifier.dart';
import 'package:memory_map/features/memory/application/story_map_state.dart';
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
  group('Story Map composition startup', () {
    test('shouldLoadOnceWhenOnlyStoryMapProviderIsWatched', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final loadedState = Completer<StoryMapState>();
      final subscription = container.listen(
        storyMapProvider('story-1'),
        (previous, next) {
          final state = next.asData?.value;
          if (state != null && !loadedState.isCompleted) {
            loadedState.complete(state);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final state = await loadedState.future;

      expect(state.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
      ]);
      expect(repository.receivedStoryIds, <String>['story-1']);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldStartLoadingFromAuthoritativeStoryMemoriesProvider', () async {
      final completer = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()..getCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final future = container.read(storyMemoriesProvider('story-1').future);

      expect(
        container.read(storyMapProvider('story-1')),
        isA<AsyncLoading<StoryMapState>>(),
      );
      expect(repository.getMemoriesCalls, 1);

      completer.complete(<Memory>[memoryA]);
      await future;
    });

    test('shouldExposeLoadedMarkersWithoutSecondRepositoryCall', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryC, memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storyMemoriesProvider('story-1').future);
      final mapState = container.read(storyMapProvider('story-1')).asData!.value;

      expect(state.memories, <Memory>[memoryC, memoryA, memoryB]);
      expect(mapState.markers.map((marker) => marker.id), <String>[
        memoryC.id,
        memoryA.id,
        memoryB.id,
      ]);
      expect(mapState.selectedMarkerId, isNull);
      expect(repository.receivedStoryIds, <String>['story-1']);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldExposeLoadedEmptyMarkersDistinctFromFailure', () async {
      final repository = FakeMemoryRepository()..memoriesResult = <Memory>[];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      await container.read(storyMemoriesProvider('story-1').future);
      final mapState = container.read(storyMapProvider('story-1')).asData!.value;

      expect(mapState.markers, isEmpty);
      expect(mapState.loadFailure, isNull);
      expect(mapState.hasLoadFailure, isFalse);
      expect(repository.getMemoriesCalls, 1);
    });

    test('shouldPreserveKnownLoadFailure', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      await container.read(storyMemoriesProvider('story-1').future);
      final mapState = container.read(storyMapProvider('story-1')).asData!.value;

      expect(mapState.markers, isEmpty);
      expect(mapState.loadFailure, const MemoryStoryUnavailable());
      expect(mapState.hasLoadFailure, isTrue);
      expect(repository.getMemoriesCalls, 1);
    });

    test('shouldPreserveUnexpectedAsyncError', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(const UnexpectedMemoryException());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<StoryMapState>>();
      final subscription = container.listen(
        storyMapProvider('story-1'),
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
      expect(repository.getMemoriesCalls, 1);
    });
  });

  group('Story Map selection', () {
    test('shouldSelectExistingMarkerWithoutNetworkCall', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryA.id);

      expect(readMapState(container, 'story-1').selectedMarkerId, memoryA.id);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldIgnoreUnknownAndBlankSelectionWithoutNetworkCall', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      final notifier = container.read(
        storyMapSelectionProvider('story-1').notifier,
      );

      notifier.selectMarker('unknown-memory');
      notifier.selectMarker('   ');

      expect(readMapState(container, 'story-1').selectedMarkerId, isNull);
      expect(repository.getMemoriesCalls, 1);
    });

    test('shouldClearSelectionWithoutNetworkCall', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      final notifier = container.read(
        storyMapSelectionProvider('story-1').notifier,
      );

      notifier.selectMarker(memoryA.id);
      notifier.clearSelection();

      expect(readMapState(container, 'story-1').selectedMarkerId, isNull);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.operations, <String>['getMemories']);
    });
  });

  group('Story Map synchronization', () {
    test('shouldReflectCreateUpsertAndKeepExistingSelection', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryA.id);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(memoryC);

      final mapState = readMapState(container, 'story-1');
      expect(mapState.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
        memoryC.id,
      ]);
      expect(mapState.selectedMarkerId, memoryA.id);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldReflectEditedLocationAndKeepSelection', () async {
      final updatedB = memory(
        id: memoryB.id,
        latitude: -12.0464,
        longitude: -77.0428,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryB.id);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertMemory(updatedB);

      final marker = readMapState(container, 'story-1')
          .markers
          .singleWhere((marker) => marker.id == memoryB.id);
      expect(marker.coordinate.latitude, -12.0464);
      expect(marker.coordinate.longitude, -77.0428);
      expect(readMapState(container, 'story-1').selectedMarkerId, memoryB.id);
      expect(repository.operations, <String>['getMemories']);
    });

    test('shouldClearSelectionWhenSelectedMemoryIsDeleted', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryB.id);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .removeMemoryById(memoryB.id);

      final mapState = readMapState(container, 'story-1');
      expect(mapState.markers.map((marker) => marker.id), <String>[memoryA.id]);
      expect(mapState.selectedMarkerId, isNull);
    });

    test('shouldKeepSelectionWhenAnotherMemoryIsDeleted', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryB.id);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .removeMemoryById(memoryA.id);

      final mapState = readMapState(container, 'story-1');
      expect(mapState.markers.map((marker) => marker.id), <String>[memoryB.id]);
      expect(mapState.selectedMarkerId, memoryB.id);
    });

    test('shouldClearSelectionWhenRefreshRemovesSelectedMarker', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryB.id);
      repository.memoriesResult = <Memory>[memoryA];

      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();

      final mapState = readMapState(container, 'story-1');
      expect(mapState.markers.map((marker) => marker.id), <String>[memoryA.id]);
      expect(mapState.selectedMarkerId, isNull);
      expect(repository.getMemoriesCalls, 2);
    });

    test('shouldKeepSelectionWhenRefreshRetainsSelectedMarker', () async {
      final updatedB = memory(
        id: memoryB.id,
        latitude: -12.0464,
        longitude: -77.0428,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryB.id);
      repository.memoriesResult = <Memory>[memoryA, updatedB];

      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();

      final mapState = readMapState(container, 'story-1');
      final marker = mapState.markers.singleWhere(
        (marker) => marker.id == memoryB.id,
      );
      expect(marker.coordinate.latitude, -12.0464);
      expect(marker.coordinate.longitude, -77.0428);
      expect(mapState.selectedMarkerId, memoryB.id);
    });
  });

  group('Story Map refresh semantics', () {
    test('shouldKeepMarkersAndSelectionWhileRefreshing', () async {
      final refreshCompleter = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryA.id);
      repository.getCompleter = refreshCompleter;

      final refresh = container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();
      await pumpEventQueue();

      final mapState = readMapState(container, 'story-1');
      expect(mapState.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
      ]);
      expect(mapState.selectedMarkerId, memoryA.id);
      expect(mapState.isRefreshing, isTrue);

      refreshCompleter.complete(<Memory>[memoryA, memoryB]);
      await refresh;
    });

    test('shouldKeepMarkersSelectionAndExposeRefreshFailure', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryB.id);
      repository.getFailures.add(
        const MemoryApplicationException(MemoryNetworkUnavailable()),
      );

      await container
          .read(storyMemoriesProvider('story-1').notifier)
          .refreshMemories();

      final mapState = readMapState(container, 'story-1');
      expect(mapState.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
      ]);
      expect(mapState.selectedMarkerId, memoryB.id);
      expect(mapState.refreshFailure, const MemoryNetworkUnavailable());
    });
  });

  group('Story Map family isolation and privacy', () {
    test('shouldKeepIndependentSelectionPerStoryId', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResults.add(<Memory>[memoryA])
        ..memoriesResults.add(<Memory>[memoryForStory2]);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);
      await container.read(storyMemoriesProvider('story-2').future);

      container
          .read(storyMapSelectionProvider('story-1').notifier)
          .selectMarker(memoryA.id);

      expect(readMapState(container, 'story-1').selectedMarkerId, memoryA.id);
      expect(readMapState(container, 'story-2').selectedMarkerId, isNull);
      expect(repository.receivedStoryIds, <String>['story-1', 'story-2']);
      expect(repository.getMemoriesCalls, 2);
    });

    test('shouldNotExposeStoryMemoryCoordinatesOrContentInDiagnostics',
        () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[
          memory(
            id: 'memory-secret',
            storyId: 'story-secret',
            title: 'Private title',
            description: 'Private description',
            placeName: 'Private place',
            latitude: 41.715123,
            longitude: 44.827456,
          ),
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-secret').future);
      container
          .read(storyMapSelectionProvider('story-secret').notifier)
          .selectMarker('memory-secret');

      final text = container.read(storyMapProvider('story-secret')).toString();
      final selectionText = container
          .read(storyMapSelectionProvider('story-secret'))
          .toString();

      expect(text, isNot(contains('story-secret')));
      expect(text, isNot(contains('memory-secret')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(selectionText, isNot(contains('memory-secret')));
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

StoryMapState readMapState(ProviderContainer container, String storyId) {
  return container.read(storyMapProvider(storyId)).asData!.value;
}

Memory memory({
  required String id,
  String storyId = 'story-1',
  String title = 'Memory title',
  String? description = 'Memory description',
  String? placeName = 'Memory place',
  double latitude = 41.7151,
  double longitude = 44.8271,
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
    location: MemoryLocation(latitude: latitude, longitude: longitude),
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
