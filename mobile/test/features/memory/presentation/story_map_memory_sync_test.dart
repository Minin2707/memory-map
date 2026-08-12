import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/application/create_memory_notifier.dart';
import 'package:memory_map/features/memory/application/delete_memory_notifier.dart';
import 'package:memory_map/features/memory/application/edit_memory_notifier.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/story_map_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('Story map memory reconciliation', () {
    testWidgets('shouldAddCreatedMemoryWithoutAutoSelectingOrRefetching', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB]
        ..createResult = memoryC;
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryA.id);
      await tester.pumpAndSettle();
      keepCreateProviderAlive(container, defaultStoryId);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput(title: memoryC.title));
      await tester.pumpAndSettle();

      expect(result, same(memoryC));
      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
        memoryC.id,
      ]);
      expect(mapSpy.latest.selectedMarkerId, memoryA.id);
      expect(find.text('First picnic'), findsOneWidget);
      expect(find.text('Quiet evening'), findsNothing);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.operations, <String>['getMemories', 'createMemory']);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldUpdatePreviewForTitleEditWithoutChangingMarkers', (
      tester,
    ) async {
      final updatedB = memory(
        id: memoryB.id,
        title: 'Updated beach title',
        latitude: memoryB.location.latitude,
        longitude: memoryB.location.longitude,
        day: memoryB.eventDate.day,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB]
        ..updateResult = updatedB;
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      final markersBefore = List<MapMarker>.of(mapSpy.latest.markers);
      keepEditProviderAlive(container, memoryB.id);
      await container.read(editMemoryProvider(memoryB.id).future);

      final result = await container
          .read(editMemoryProvider(memoryB.id).notifier)
          .save(
            UpdateMemoryInput(
              memoryId: memoryB.id,
              title: const MemoryUpdateField<String>.provided(
                'Updated beach title',
              ),
            ),
          );
      await tester.pumpAndSettle();

      expect(result, same(updatedB));
      expect(mapSpy.latest.markers, markersBefore);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(find.text('Beach morning'), findsNothing);
      expect(find.text('Updated beach title'), findsOneWidget);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.operations, <String>['getMemories', 'updateMemory']);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldReorderMarkersAfterEventDateEditAndKeepSelection', (
      tester,
    ) async {
      final updatedB = memory(
        id: memoryB.id,
        title: memoryB.title,
        latitude: memoryB.location.latitude,
        longitude: memoryB.location.longitude,
        day: 5,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB, memoryC]
        ..updateResult = updatedB;
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      keepEditProviderAlive(container, memoryB.id);
      await container.read(editMemoryProvider(memoryB.id).future);

      final result = await container
          .read(editMemoryProvider(memoryB.id).notifier)
          .save(
            UpdateMemoryInput(
              memoryId: memoryB.id,
              eventDate: MemoryUpdateField<MemoryDate>.provided(
                MemoryDate(year: 2026, month: 8, day: 5),
              ),
            ),
          );
      await tester.pumpAndSettle();

      expect(result, same(updatedB));
      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryB.id,
        memoryA.id,
        memoryC.id,
      ]);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(find.text('Aug 5, 2026'), findsOneWidget);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.getMemoriesCalls, 1);
    });

    testWidgets('shouldMoveSelectedMarkerAfterLocationEdit', (tester) async {
      final movedB = memory(
        id: memoryB.id,
        title: memoryB.title,
        latitude: 55.751244,
        longitude: 37.618423,
        day: memoryB.eventDate.day,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB]
        ..updateResult = movedB;
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      keepEditProviderAlive(container, memoryB.id);
      await container.read(editMemoryProvider(memoryB.id).future);

      final result = await container
          .read(editMemoryProvider(memoryB.id).notifier)
          .save(
            UpdateMemoryInput(
              memoryId: memoryB.id,
              location: MemoryUpdateField<MemoryLocation>.provided(
                movedB.location,
              ),
            ),
          );
      await tester.pumpAndSettle();

      final marker = mapSpy.latest.markers.singleWhere(
        (marker) => marker.id == memoryB.id,
      );
      expect(result, same(movedB));
      expect(marker.coordinate, movedB.location.toMapCoordinate());
      expect(
        mapSpy.latest.markers.where(
          (marker) =>
              marker.id == memoryB.id &&
              marker.coordinate == memoryB.location.toMapCoordinate(),
        ),
        isEmpty,
      );
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(find.text('Beach morning'), findsOneWidget);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.getMemoriesCalls, 1);
    });

    testWidgets('shouldRemoveDeletedSelectedMemoryAfterBackendSuccess', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      keepDeleteProviderAlive(container, memoryB.id);
      await container.read(deleteMemoryProvider(memoryB.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryB.id).notifier)
          .deleteMemory(memoryB);
      await tester.pumpAndSettle();

      expect(success, isTrue);
      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryA.id,
      ]);
      expect(mapSpy.latest.selectedMarkerId, isNull);
      expect(
        find.byKey(const ValueKey('story-map.memory-preview')),
        findsNothing,
      );
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.operations, <String>['getMemories', 'deleteMemory']);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldPreserveMapWhenDeleteFails', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB]
        ..deleteFailure = const MemoryApplicationException(
          MemoryDeletionUnavailable(),
        );
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      keepDeleteProviderAlive(container, memoryB.id);
      await container.read(deleteMemoryProvider(memoryB.id).future);

      final success = await container
          .read(deleteMemoryProvider(memoryB.id).notifier)
          .deleteMemory(memoryB);
      await tester.pumpAndSettle();

      expect(success, isFalse);
      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
      ]);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(find.text('Beach morning'), findsOneWidget);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.operations, <String>['getMemories', 'deleteMemory']);
      expect(repository.getMemoriesCalls, 1);
    });

    testWidgets('shouldApplyRefreshAuthoritativeReplaceExactly', (
      tester,
    ) async {
      final refreshedB = memory(
        id: memoryB.id,
        title: 'Authoritative beach',
        latitude: 55.751244,
        longitude: 37.618423,
        day: memoryB.eventDate.day,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      repository.memoriesResult = <Memory>[memoryC, refreshedB];

      await container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .refreshMemories();
      await tester.pumpAndSettle();

      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryC.id,
        memoryB.id,
      ]);
      expect(
        mapSpy.latest.markers.singleWhere((marker) => marker.id == memoryB.id)
            .coordinate,
        refreshedB.location.toMapCoordinate(),
      );
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(find.text('Authoritative beach'), findsOneWidget);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.operations, <String>['getMemories', 'getMemories']);
      expect(repository.getMemoriesCalls, 2);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldPreserveMapAndPreviewWhenRefreshFails', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      final markersBefore = List<MapMarker>.of(mapSpy.latest.markers);
      repository.getFailures.add(
        const MemoryApplicationException(MemoryNetworkUnavailable()),
      );

      await container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .refreshMemories();
      await tester.pumpAndSettle();

      expect(mapSpy.latest.markers, markersBefore);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(find.text('Beach morning'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-map.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.operations, <String>['getMemories', 'getMemories']);
      expect(repository.getMemoriesCalls, 2);
    });

    testWidgets('shouldKeepDistinctMarkersWithDuplicateCoordinates', (
      tester,
    ) async {
      final duplicateCoordinateB = memory(
        id: memoryB.id,
        title: memoryB.title,
        latitude: memoryA.location.latitude,
        longitude: memoryA.location.longitude,
        day: memoryB.eventDate.day,
      );
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, duplicateCoordinateB];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);

      expect(mapSpy.latest.markers.length, 2);
      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
      ]);
      expect(
        mapSpy.latest.markers[0].coordinate,
        mapSpy.latest.markers[1].coordinate,
      );
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.getMemoriesCalls, 1);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
  required FakeStoryMapSpy mapSpy,
}) async {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StoryMapScreen(
          storyId: defaultStoryId,
          mapBuilder: mapSpy.build,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

void keepCreateProviderAlive(ProviderContainer container, String storyId) {
  final subscription = container.listen(
    createMemoryProvider(storyId),
    (_, __) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
}

void keepEditProviderAlive(ProviderContainer container, String memoryId) {
  final subscription = container.listen(
    editMemoryProvider(memoryId),
    (_, __) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
}

void keepDeleteProviderAlive(ProviderContainer container, String memoryId) {
  final subscription = container.listen(
    deleteMemoryProvider(memoryId),
    (_, __) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
}

CreateMemoryInput createInput({
  String title = 'New memory',
}) {
  return CreateMemoryInput(
    storyId: defaultStoryId,
    title: title,
    location: memoryC.location,
    eventDate: memoryC.eventDate,
  );
}

Memory memory({
  String id = '00000000-0000-0000-0000-000000000001',
  String storyId = defaultStoryId,
  String title = 'First picnic',
  String? description = 'Private note',
  String? placeName = 'Private place',
  double latitude = 41.7151,
  double longitude = 44.8271,
  int day = 9,
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
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultStoryId = 'story-id';

final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'First picnic',
  latitude: 41.7151,
  longitude: 44.8271,
  day: 10,
);

final Memory memoryB = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'Beach morning',
  latitude: -12.0464,
  longitude: -77.0428,
  day: 15,
);

final Memory memoryC = memory(
  id: '00000000-0000-0000-0000-000000000003',
  title: 'Quiet evening',
  latitude: 55.751244,
  longitude: 37.618423,
  day: 20,
);

final class FakeStoryMapSpy {
  final List<StoryMapViewConfiguration> configurations =
      <StoryMapViewConfiguration>[];

  StoryMapViewConfiguration get latest => configurations.last;

  List<int> get distinctCameraRevisions {
    final revisions = <int>[];
    for (final configuration in configurations) {
      final revision = configuration.cameraCommand?.revision;
      if (revision != null &&
          (revisions.isEmpty || revisions.last != revision)) {
        revisions.add(revision);
      }
    }

    return revisions;
  }

  Widget build(
    BuildContext context,
    StoryMapViewConfiguration configuration,
  ) {
    configurations.add(configuration);

    return Center(
      key: const ValueKey('story-map.fake-map'),
      child: Text('Fake map markers: ${configuration.markers.length}'),
    );
  }
}

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  List<Memory> memoriesResult = <Memory>[];
  Memory createResult = memoryC;
  Memory updateResult = memoryB;
  Memory memoryResult = memoryA;
  Object? createFailure;
  Object? updateFailure;
  Object? deleteFailure;
  final List<Object> getFailures = <Object>[];
  final List<String> operations = <String>[];

  @override
  Future<List<Memory>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    operations.add('getMemories');

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    return memoriesResult;
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    operations.add('getMemory');
    return memoryResult;
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    operations.add('createMemory');

    final failure = createFailure;
    if (failure != null) {
      throw failure;
    }

    return createResult;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    operations.add('updateMemory');

    final failure = updateFailure;
    if (failure != null) {
      throw failure;
    }

    return updateResult;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
    operations.add('deleteMemory');

    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

extension on MemoryLocation {
  MapCoordinate toMapCoordinate() {
    return MapCoordinate(latitude: latitude, longitude: longitude);
  }
}
