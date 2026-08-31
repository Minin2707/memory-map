import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/story_map_screen.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('StoryMapScreen rendering', () {
    testWidgets('shouldRenderInitialLoadingWithoutMap', (tester) async {
      final completer = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()..getCompleter = completer;
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy, settle: false);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('story-map.loading-view')),
        findsOneWidget,
      );
      expect(mapSpy.configurations, isEmpty);
      expect(find.textContaining('Dio'), findsNothing);

      completer.complete(<Memory>[memoryA]);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderLoadedMarkersThroughMapBoundary', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final storyRepository = FakeStoryRepository()
        ..storyResult = userStory(
          title: 'Our story',
          memoryCount: 24,
        );
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(
        tester,
        repository,
        storyRepository: storyRepository,
        mapSpy: mapSpy,
      );

      expect(find.text('Our story'), findsOneWidget);
      expect(find.text('24 memories'), findsOneWidget);
      expect(find.text('Map'), findsNothing);
      expect(find.text('Fake map markers: 2'), findsOneWidget);
      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
      ]);
      expect(mapSpy.latest.sourceConfiguration, MapSources.openFreeMapLiberty);
      expect(mapSpy.latest.selectedMarkerId, isNull);
      expect(storyRepository.receivedGetStoryIds, <String>[defaultStoryId]);
    });

    testWidgets('shouldPassPhotoMarkerProjectionThroughMapBoundary', (
      tester,
    ) async {
      final preview = memoryPreviewPhoto(mediaId: 'memory-media');
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          MemoryReadModel(memory: memoryA, previewPhoto: preview),
          MemoryReadModel.fromMemory(memoryB),
        ];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);

      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
      ]);
      expect(
        mapSpy.latest.markerPresentations.map(
          (presentation) => presentation.previewPhoto,
        ),
        <MemoryPhotoPreview?>[preview, null],
      );
      expect(mapSpy.latest.toString(), isNot(contains('/api/v1/media')));
      expect(mapSpy.latest.toString(), isNot(contains('memory-media')));
    });

    testWidgets('shouldRenderStoryThumbnailThroughAuthenticatedPath', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository();

      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(
            previewPhoto: storyPreviewPhoto(mediaId: 'story-media'),
          ),
        mediaRepository: mediaRepository,
        mapSpy: FakeStoryMapSpy(),
      );

      expect(
        find.byKey(
          const ValueKey(
            'story-map.header-thumbnail./api/v1/media/story-media/thumbnail',
          ),
        ),
        findsOneWidget,
      );
      expect(
        mediaRepository.receivedBinaryPaths,
        contains('/api/v1/media/story-media/thumbnail'),
      );
      expect(mediaRepository.getDisplayByPathCalls, 0);
      expect(mediaRepository.getMediaCalls, 0);
    });

    testWidgets('shouldRenderNoStoryPreviewFallback', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(
            title: 'Quiet archive',
            memoryCount: 1,
          ),
        mapSpy: FakeStoryMapSpy(),
      );

      expect(find.text('Quiet archive'), findsOneWidget);
      expect(find.text('1 memory'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-map.header.no-photo')),
        findsOneWidget,
      );
    });

    testWidgets('shouldTreatStoryThumbnailFailureAsSafeFallback', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailFailure = Object();

      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(
            previewPhoto: storyPreviewPhoto(mediaId: 'broken-story-media'),
          ),
        mediaRepository: mediaRepository,
        mapSpy: FakeStoryMapSpy(),
      );

      expect(find.text('Fake map markers: 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-map.header.no-photo')),
        findsOneWidget,
      );
    });

    testWidgets('shouldKeepLoadedMapVisibleWhileStoryHeaderIsLoading', (
      tester,
    ) async {
      final storyCompleter = Completer<UserStory>();
      final storyRepository = FakeStoryRepository()
        ..getStoryCompleter = storyCompleter;
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        storyRepository: storyRepository,
        mapSpy: mapSpy,
        settle: false,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('story-map.header.thumbnail-loading')),
        findsOneWidget,
      );
      expect(find.text('Fake map markers: 1'), findsOneWidget);
      expect(mapSpy.configurations, isNotEmpty);

      storyCompleter.complete(ownerStory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderEmptyMapAndInformationalEmptyState', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()..memoriesResult = <Memory>[];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(
        tester,
        repository,
        mapSpy: mapSpy,
        onMemorySelected: (_) {},
      );

      expect(find.text('Fake map markers: 0'), findsOneWidget);
      expect(find.text('No memories on the map yet'), findsOneWidget);
      expect(
        find.text('Memories with saved places will appear here.'),
        findsOneWidget,
      );
      expect(find.text('Add memory'), findsNothing);
      expect(
        find.byKey(const ValueKey('story-map.memory-preview')),
        findsNothing,
      );
      expect(
        mapSpy.latest.cameraCommand!.target.type,
        MapCameraTargetType.neutral,
      );
    });

    testWidgets('shouldRenderRussianCopy', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[],
        locale: const Locale('ru'),
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(
            title: 'Наша история',
            memoryCount: 0,
          ),
        mapSpy: FakeStoryMapSpy(),
      );

      expect(find.text('Наша история'), findsOneWidget);
      expect(find.text('Нет воспоминаний'), findsOneWidget);
      expect(find.text('На карте пока нет воспоминаний'), findsOneWidget);
    });
  });

  group('StoryMapScreen failures', () {
    testWidgets('shouldRenderKnownLoadFailureSafelyAndRetry', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        )
        ..memoriesResult = <Memory>[memoryA];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);

      expect(find.text('Could not load map'), findsOneWidget);
      expect(find.text('Story memories are unavailable.'), findsOneWidget);
      expect(mapSpy.configurations, isEmpty);
      expect(find.textContaining('MemoryApplicationException'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.error.retry-action')),
      );

      expect(repository.getMemoriesCalls, 2);
      expect(find.text('Fake map markers: 1'), findsOneWidget);
    });

    testWidgets('shouldRenderUnexpectedAsyncErrorSafely', (tester) async {
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..getFailures.add(const UnexpectedMemoryException()),
        mapSpy: mapSpy,
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(mapSpy.configurations, isEmpty);
      expect(find.textContaining('UnexpectedMemoryException'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });
  });

  group('StoryMapScreen refresh', () {
    testWidgets('shouldKeepMarkersVisibleWhileRefreshing', (tester) async {
      final refreshCompleter = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      repository.getCompleter = refreshCompleter;

      final refresh = container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .refreshMemories();
      await tester.pump();

      expect(find.text('Fake map markers: 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      refreshCompleter.complete(<Memory>[memoryB]);
      await refresh;
      await tester.pumpAndSettle();

      expect(find.text('Fake map markers: 1'), findsOneWidget);
      expect(mapSpy.latest.markers.single.id, memoryB.id);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
    });

    testWidgets('shouldRenderRefreshFailureBannerAndRetry', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final mapSpy = FakeStoryMapSpy();
      await pumpScreen(tester, repository, mapSpy: mapSpy);
      repository.getFailures.add(
        const MemoryApplicationException(MemoryRequestTimedOut()),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.refresh-action')),
      );

      expect(find.text('Fake map markers: 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-map.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Could not refresh map. The request timed out. Please try again.',
        ),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.refresh.retry-action')),
      );

      expect(repository.getMemoriesCalls, 3);
    });

    testWidgets('shouldUpdateSelectedPreviewAfterRefreshSuccess', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      repository.memoriesResult = <Memory>[
        memoryA,
        memory(
          id: memoryB.id,
          title: 'Backend beach',
          placeName: 'Backend shore',
          day: 22,
        ),
      ];

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.refresh-action')),
      );

      expect(find.text('Backend beach'), findsOneWidget);
      expect(find.text('Backend shore'), findsOneWidget);
      expect(find.text('Aug 22, 2026'), findsOneWidget);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldHideSelectedPreviewWhenRefreshRemovesMemory', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      repository.memoriesResult = <Memory>[memoryA];

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.refresh-action')),
      );

      expect(
        find.byKey(const ValueKey('story-map.memory-preview')),
        findsNothing,
      );
      expect(mapSpy.latest.selectedMarkerId, isNull);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldKeepSelectedPreviewOnRefreshFailure', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();
      repository.getFailures.add(
        const MemoryApplicationException(MemoryNetworkUnavailable()),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.refresh-action')),
      );

      expect(find.text('Beach morning'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-map.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(repository.getMemoryCalls, 0);
    });
  });

  group('StoryMapScreen selection and camera', () {
    testWidgets('shouldSelectMarkerAndShowPreviewWithoutSecondLookup', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(
        tester,
        repository,
        mapSpy: mapSpy,
        onMemorySelected: (_) {},
      );
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(find.text('Beach morning'), findsOneWidget);
      expect(find.text('Aug 15, 2026'), findsOneWidget);
      expect(find.text('Private place'), findsOneWidget);
      expect(find.text('Private note'), findsOneWidget);
      expect(find.text('Show details'), findsOneWidget);
      expect(find.text('Fake map markers: 2'), findsOneWidget);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldRenderSelectedPreviewOptionalContent', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[
          memory(
            id: memoryA.id,
            title: 'Quiet title',
            description: null,
            placeName: null,
          ),
        ];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryA.id);
      await tester.pumpAndSettle();

      expect(find.text('Quiet title'), findsOneWidget);
      expect(find.text('Private note'), findsNothing);
      expect(find.text('Private place'), findsNothing);
      expect(
        find.byKey(const ValueKey('story-map.memory-preview.no-photo')),
        findsOneWidget,
      );
    });

    testWidgets('shouldRenderSelectedPreviewAuthenticatedThumbnail', (
      tester,
    ) async {
      final preview = memoryPreviewPhoto(mediaId: 'selected-media');
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          MemoryReadModel(memory: memoryA, previewPhoto: preview),
        ];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryA.id);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('story-map.memory-preview.photo.selected-media'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.textContaining('selected-media'), findsNothing);
    });

    testWidgets('shouldSwitchPreviewWhenAnotherMarkerIsSelected', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryA.id);
      await tester.pumpAndSettle();
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      expect(find.text('First picnic'), findsNothing);
      expect(find.text('Beach morning'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-map.memory-preview')),
        findsOneWidget,
      );
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldClearPreviewAndSelectedMarkerWithoutMovingCamera', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.memory-preview.close')),
      );

      expect(
        find.byKey(const ValueKey('story-map.memory-preview')),
        findsNothing,
      );
      expect(mapSpy.latest.selectedMarkerId, isNull);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldEmitOpenDetailsIntentWithExactMemoryOnlyOnDetailsAction', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      Memory? openedMemory;

      await pumpScreen(
        tester,
        repository,
        mapSpy: mapSpy,
        onMemorySelected: (memory) {
          openedMemory = memory;
        },
      );
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      expect(openedMemory, isNull);

      await pressButton(
        tester,
        find.byKey(
          const ValueKey('story-map.memory-preview.details-action'),
        ),
      );

      expect(openedMemory, same(memoryB));
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldRenderNonInteractivePreviewWithoutOpenCallback', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      expect(find.text('Beach morning'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('story-map.memory-preview.details-action'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('story-map.memory-preview')));
      await tester.pump();

      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldUpdatePreviewFromEditedSelectedMemory', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      final updatedB = memory(
        id: memoryB.id,
        title: 'Updated beach',
        placeName: 'Updated shore',
        day: 21,
      );
      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertMemory(updatedB);
      await tester.pumpAndSettle();

      expect(find.text('Beach morning'), findsNothing);
      expect(find.text('Updated beach'), findsOneWidget);
      expect(find.text('Updated shore'), findsOneWidget);
      expect(find.text('Aug 21, 2026'), findsOneWidget);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldKeepPreviewWhenSelectedMemoryLocationChanges', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      final movedB = memory(
        id: memoryB.id,
        title: memoryB.title,
        latitude: 55.751244,
        longitude: 37.618423,
        day: 15,
      );
      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertMemory(movedB);
      await tester.pumpAndSettle();

      final marker = mapSpy.latest.markers.singleWhere(
        (marker) => marker.id == memoryB.id,
      );
      expect(find.text('Beach morning'), findsOneWidget);
      expect(marker.coordinate.latitude, 55.751244);
      expect(marker.coordinate.longitude, 37.618423);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldHidePreviewWhenSelectedMemoryIsDeleted', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .removeMemoryById(memoryB.id);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-map.memory-preview')),
        findsNothing,
      );
      expect(mapSpy.latest.selectedMarkerId, isNull);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldKeepPreviewWhenAnotherMemoryIsDeleted', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .removeMemoryById(memoryA.id);
      await tester.pumpAndSettle();

      expect(find.text('Beach morning'), findsOneWidget);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldKeepCurrentPreviewWhenAnotherMemoryIsCreated', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);
      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertMemory(memoryC);
      await tester.pumpAndSettle();

      expect(find.text('Beach morning'), findsOneWidget);
      expect(find.text('Quiet evening'), findsNothing);
      expect(mapSpy.latest.selectedMarkerId, memoryB.id);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldApplyInitialCameraOnlyOnce', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);

      mapSpy.latest.onMarkerSelected(memoryB.id);
      await tester.pumpAndSettle();

      expect(mapSpy.distinctCameraRevisions, <int>[1]);
    });

    testWidgets('shouldNotResetCameraWhenMarkersChangeAfterInitialLoad', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertMemory(memoryC);
      await tester.pumpAndSettle();

      expect(mapSpy.latest.markers.map((marker) => marker.id), <String>[
        memoryA.id,
        memoryB.id,
        memoryC.id,
      ]);
      expect(mapSpy.distinctCameraRevisions, <int>[1]);
    });

    testWidgets('shouldApplyShowAllEveryTimeUsingCurrentMarkers', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();
      final container = await pumpScreen(tester, repository, mapSpy: mapSpy);

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertMemory(memoryC);
      await tester.pumpAndSettle();

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.show-all-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.show-all-action')),
      );

      expect(mapSpy.distinctCameraRevisions, <int>[1, 2, 3]);
      expect(
        mapSpy.latest.cameraCommand!.target.type,
        MapCameraTargetType.bounds,
      );
      expect(mapSpy.latest.cameraCommand!.target.northeast!.latitude, 55.751244);
    });

    testWidgets('shouldApplyNeutralShowAllForEmptyMap', (tester) async {
      final repository = FakeMemoryRepository()..memoriesResult = <Memory>[];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.show-all-action')),
      );

      expect(mapSpy.distinctCameraRevisions, <int>[1, 2]);
      expect(
        mapSpy.latest.cameraCommand!.target.type,
        MapCameraTargetType.neutral,
      );
    });

    testWidgets('shouldApplyInitialCameraAfterRetrySuccess', (tester) async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryNetworkUnavailable()),
        )
        ..memoriesResult = <Memory>[memoryA, memoryB];
      final mapSpy = FakeStoryMapSpy();

      await pumpScreen(tester, repository, mapSpy: mapSpy);
      expect(mapSpy.configurations, isEmpty);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.error.retry-action')),
      );

      expect(mapSpy.distinctCameraRevisions, <int>[1]);
      expect(
        mapSpy.latest.cameraCommand!.target.type,
        MapCameraTargetType.bounds,
      );
    });
  });

  group('StoryMapScreen callbacks and privacy', () {
    testWidgets('shouldCallBackWithoutRouterImport', (tester) async {
      var backCalls = 0;

      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        mapSpy: FakeStoryMapSpy(),
        onBack: () {
          backCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-map.back-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(backCalls, 2);
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (tester) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        mapSpy: FakeStoryMapSpy(),
        textScaler: const TextScaler.linear(1.25),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotRenderIdsCoordinatesSourceUriOrRawFailures', (
      tester,
    ) async {
      final mapSpy = FakeStoryMapSpy();
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoriesResult = <Memory>[
            memory(
              id: 'private-memory-id',
              storyId: 'private-story-id',
              createdBy: 'private-user-id',
              title: 'Visible private memory',
              latitude: 41.715123,
              longitude: 44.827456,
            ),
          ],
        storyId: 'private-story-id',
        sourceConfiguration: MapSourceConfiguration(
          styleUri: 'https://example.invalid/SECRET/style.json',
        ),
        mapSpy: mapSpy,
      );
      mapSpy.latest.onMarkerSelected('private-memory-id');
      await tester.pumpAndSettle();

      expect(find.text('Visible private memory'), findsOneWidget);
      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('41.715123'), findsNothing);
      expect(find.textContaining('44.827456'), findsNothing);
      expect(find.textContaining('https://example.invalid'), findsNothing);
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('ProblemDetail'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
    });

    test('shouldHaveSafeMapBoundaryDiagnostics', () {
      final configuration = StoryMapViewConfiguration(
        markers: <MapMarker>[
          MapMarker(
            id: 'private-memory-id',
            coordinate: MemoryLocation(
              latitude: 41.715123,
              longitude: 44.827456,
            ).toMapCoordinate(),
          ),
        ],
        sourceConfiguration: MapSourceConfiguration(
          styleUri: 'https://example.invalid/SECRET/style.json',
        ),
        selectedMarkerId: 'private-memory-id',
        onMarkerSelected: (_) {},
        cameraCommand: MapCameraCommand(
          revision: 1,
          target: MapCameraTarget.point(
            coordinate: MemoryLocation(
              latitude: 41.715123,
              longitude: 44.827456,
            ).toMapCoordinate(),
            zoom: 12,
          ),
        ),
      );

      final text = configuration.toString();

      expect(text, contains('markerCount: 1'));
      expect(text, contains('hasSelection: true'));
      expect(text, contains('hasCameraCommand: true'));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(text, isNot(contains('https://example.invalid')));
      expect(text, isNot(contains('SECRET')));
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
  FakeStoryRepository? storyRepository,
  media_fixtures.FakeMediaRepository? mediaRepository,
  String storyId = defaultStoryId,
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  ValueChanged<Memory>? onMemorySelected,
  MapSourceConfiguration sourceConfiguration = MapSources.openFreeMapLiberty,
  required FakeStoryMapSpy mapSpy,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
      storyRepositoryProvider.overrideWithValue(
        storyRepository ?? FakeStoryRepository(),
      ),
      mediaRepositoryProvider.overrideWithValue(
        mediaRepository ?? media_fixtures.FakeMediaRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: StoryMapScreen(
          storyId: storyId,
          onBack: onBack,
          onMemorySelected: onMemorySelected,
          sourceConfiguration: sourceConfiguration,
          mapBuilder: mapSpy.build,
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  }

  return container;
}

Future<void> pressButton(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  final widget = tester.widget<Widget>(finder);
  final onPressed = switch (widget) {
    FilledButton(:final onPressed) => onPressed,
    OutlinedButton(:final onPressed) => onPressed,
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    _ => throw StateError('Unsupported button widget: $widget'),
  };

  onPressed?.call();

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

UserStory userStory({
  String id = defaultStoryId,
  String title = 'Our story',
  StoryRole role = StoryRole.owner,
  int memoryCount = 3,
  StoryPhotoPreview? previewPhoto,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: 'Together',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
    memoryCount: memoryCount,
    participantCount: 2,
    previewPhoto: previewPhoto,
  );
}

StoryPhotoPreview storyPreviewPhoto({
  required String mediaId,
}) {
  return StoryPhotoPreview(
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
    displayPath: '/api/v1/media/$mediaId/display',
  );
}

MemoryPhotoPreview memoryPreviewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

Memory memory({
  String id = '00000000-0000-0000-0000-000000000001',
  String storyId = defaultStoryId,
  String createdBy = 'author-id',
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
    createdBy: createdBy,
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

final UserStory ownerStory = userStory();

final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'First picnic',
  latitude: 41.7151,
  longitude: 44.8271,
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
  Completer<List<Memory>>? getCompleter;
  List<Memory> memoriesResult = <Memory>[];
  List<MemoryReadModel>? memoryReadModelsResult;
  final List<Object> getFailures = <Object>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;

    final configuredCompleter = getCompleter;
    if (configuredCompleter != null) {
      getCompleter = null;
      return configuredCompleter.future.then(_readModelsFromMemories);
    }

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    return memoryReadModelsResult ?? _readModelsFromMemories(memoriesResult);
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    return MemoryReadModel.fromMemory(memoryA);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    return memoryA;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    return memoryA;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
  }
}

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  UserStory storyResult = ownerStory;
  Completer<UserStory>? getStoryCompleter;
  final List<String> receivedGetStoryIds = <String>[];

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    return <UserStory>[storyResult];
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    receivedGetStoryIds.add(storyId);

    final completer = getStoryCompleter;
    if (completer != null) {
      getStoryCompleter = null;
      return completer.future;
    }

    return storyResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    return storyResult;
  }

  @override
  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> removeStoryCover({
    required String storyId,
  }) async {
    throw UnimplementedError();
  }
}

List<MemoryReadModel> _readModelsFromMemories(List<Memory> memories) {
  return memories.map(MemoryReadModel.fromMemory).toList();
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}

extension on MemoryLocation {
  MapCoordinate toMapCoordinate() {
    return MapCoordinate(latitude: latitude, longitude: longitude);
  }
}


