import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
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
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/playback/application/playback_scheduler.dart';
import 'package:memory_map/features/playback/application/playback_scheduler_provider.dart';
import 'package:memory_map/features/playback/presentation/story_playback_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('StoryPlaybackScreen state composition', () {
    testWidgets('shouldRenderLoadingState', (tester) async {
      final repository = FakeMemoryRepository()
        ..getCompleter = Completer<List<MemoryReadModel>>();

      await pumpPlaybackScreen(tester, repository, settle: false);
      await tester.pump();

      expect(find.byKey(const ValueKey('story-playback.loading')), findsOneWidget);
      expect(find.text('Story playback'), findsOneWidget);
      expect(find.text('Playback'), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.close')), findsOneWidget);
      expect(find.textContaining('story-1'), findsNothing);
    });

    testWidgets('shouldRenderEmptyStateAndClose', (tester) async {
      var closeCalls = 0;
      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository(),
        onClose: () {
          closeCalls += 1;
        },
      );

      expect(find.byKey(const ValueKey('story-playback.empty')), findsOneWidget);
      expect(find.text('No memories to play yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.pause')), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.close')),
      );

      expect(closeCalls, 1);
    });

    testWidgets('shouldRenderKnownLoadFailureAndRetrySafely', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        )
        ..memoryReadModelsResults.add(<MemoryReadModel>[readModel(memoryA)]);
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        repository,
        presentations: presentations,
      );

      expect(
        find.byKey(const ValueKey('story-playback.load-failure')),
        findsOneWidget,
      );
      expect(find.text('Playback is unavailable'), findsOneWidget);
      expect(find.textContaining('MemoryStoryUnavailable'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.retry-load')),
      );

      expect(repository.getMemoriesCalls, 2);
      expect(find.byKey(const ValueKey('story-playback.fake-map')), findsOneWidget);
      expect(presentations.last.markers.length, 1);
    });

    testWidgets('shouldRenderMovingThenPresentingWithDisplayPhoto', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..displayResult = media_fixtures.validPngBytes;
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(
              memoryB,
              previewPhoto: previewPhoto(mediaId: 'media-b'),
            ),
            readModel(
              memoryA,
              previewPhoto: previewPhoto(mediaId: 'media-a'),
            ),
          ],
        mediaRepository: mediaRepository,
        presentations: presentations,
      );

      expect(presentations.last.markers.length, 2);
      expect(find.text('Story playback'), findsOneWidget);
      expect(presentations.last.route.hasRoute, isTrue);
      expect(presentations.last.route.coordinates, <MapCoordinate>[
        MapCoordinate(
          latitude: memoryA.location.latitude,
          longitude: memoryA.location.longitude,
        ),
        MapCoordinate(
          latitude: memoryB.location.latitude,
          longitude: memoryB.location.longitude,
        ),
      ]);
      expect(presentations.last.currentIndex, 0);
      expect(presentations.last.cameraCommand, isNotNull);
      expect(presentations.last.markers.first.hasPreviewPhoto, isTrue);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsNothing,
      );
      expect(find.text('1 / 2 memories'), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.pause')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-playback.previous')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('story-playback.next')), findsNothing);
      expect(mediaRepository.getDisplayByPathCalls, 0);

      final command = presentations.last.cameraCommand!;
      presentations.last.onCameraArrived(command.revision);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsOneWidget,
      );
      expect(find.text('Sunrise picnic'), findsOneWidget);
      expect(find.text('Aug 9, 2026'), findsOneWidget);
      expect(find.text('Memory place'), findsOneWidget);
      expect(find.text('Visible description'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-playback.display-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('story-playback.previous')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('story-playback.next')), findsOneWidget);
      expect(mediaRepository.getMediaCalls, 0);
      expect(mediaRepository.getDisplayByPathCalls, 1);
      expect(mediaRepository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-a/display',
      ]);
    });

    testWidgets('shouldKeepPresentationCardHiddenWhileMoving', (
      tester,
    ) async {
      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
          ],
      );

      expect(
        find.byKey(const ValueKey('story-playback.controls')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('story-playback.pause')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-playback.previous')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('story-playback.next')), findsNothing);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('story-playback.details')), findsNothing);
      expect(find.text('Sunrise picnic'), findsNothing);
    });

    testWidgets('shouldRenderProvidedStoryTitleInOverlayChrome', (
      tester,
    ) async {
      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
          ],
        storyTitle: 'Our journey',
      );

      expect(find.text('Story playback'), findsOneWidget);
      expect(find.text('Our journey'), findsOneWidget);
      expect(find.textContaining('story-1'), findsNothing);
    });
  });

  group('StoryPlaybackScreen controls', () {
    testWidgets('shouldPauseAndResumeMovingStateThroughNotifier', (
      tester,
    ) async {
      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
          ],
      );

      expect(find.byKey(const ValueKey('story-playback.pause')), findsOneWidget);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.pause')),
      );

      expect(find.byKey(const ValueKey('story-playback.resume')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('story-playback.details')), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.resume')),
      );

      expect(find.byKey(const ValueKey('story-playback.pause')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsNothing,
      );
    });

    testWidgets('shouldPauseAndResumePresentingStateWithoutHidingCard', (
      tester,
    ) async {
      final scheduler = FakePlaybackScheduler();
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
          ],
        scheduler: scheduler,
        presentations: presentations,
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(scheduler.activeTaskCount, 1);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.pause')),
      );

      expect(find.byKey(const ValueKey('story-playback.resume')), findsOneWidget);
      expect(scheduler.activeTaskCount, 0);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.resume')),
      );

      expect(find.byKey(const ValueKey('story-playback.pause')), findsOneWidget);
      expect(scheduler.activeTaskCount, 1);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsOneWidget,
      );
    });

    testWidgets('shouldNavigatePreviousNextAndUpdateProgress', (tester) async {
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
            readModel(memoryB),
          ],
        presentations: presentations,
      );

      expect(find.text('1 / 2 memories'), findsOneWidget);

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-playback.next')), findsOneWidget);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.next')),
      );

      expect(find.text('2 / 2 memories'), findsOneWidget);
      expect(presentations.last.currentIndex, 1);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsNothing,
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-playback.previous')),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.previous')),
      );

      expect(find.text('1 / 2 memories'), findsOneWidget);
      expect(presentations.last.currentIndex, 0);
    });

    testWidgets('shouldShowFinishedStateAndReplaySameSnapshot', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final scheduler = FakePlaybackScheduler();
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        repository,
        scheduler: scheduler,
        presentations: presentations,
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();
      scheduler.latest.fire();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-playback.finished')), findsOneWidget);
      expect(find.text('Playback finished'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Playback finished')).style?.color,
        Colors.white,
      );
      expect(
        tester
            .widget<Text>(
              find.text('Replay this story journey or close playback.'),
            )
            .style
            ?.color,
        isNot(const Color(0xFF667085)),
      );
      expect(find.text('1 / 1 memory'), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.pause')), findsNothing);
      expect(find.byKey(const ValueKey('story-playback.details')), findsNothing);
      expect(find.byKey(const ValueKey('story-playback.close')), findsOneWidget);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.replay')),
      );

      expect(repository.getMemoriesCalls, 1);
      expect(find.text('1 / 1 memory'), findsOneWidget);
      expect(presentations.last.currentIndex, 0);
      expect(presentations.last.cameraCommand, isNotNull);
    });

    testWidgets('shouldPauseBeforeOpeningMemoryDetailsFromPresentingCard', (
      tester,
    ) async {
      final scheduler = FakePlaybackScheduler();
      final presentations = <PlaybackMapPresentation>[];
      final selectedMemories = <MemoryReadModel>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)],
        scheduler: scheduler,
        presentations: presentations,
        onMemoryDetailsSelected: selectedMemories.add,
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-playback.details')), findsOneWidget);
      expect(find.text('Show details'), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.pause')), findsOneWidget);
      expect(scheduler.activeTaskCount, 1);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.details')),
      );

      expect(selectedMemories.single.memory.id, memoryA.id);
      expect(find.byKey(const ValueKey('story-playback.resume')), findsOneWidget);
      expect(scheduler.activeTaskCount, 0);
    });

    testWidgets('shouldOpenMemoryDetailsFromAlreadyPausedPresentation', (
      tester,
    ) async {
      final scheduler = FakePlaybackScheduler();
      final presentations = <PlaybackMapPresentation>[];
      final selectedMemories = <MemoryReadModel>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)],
        scheduler: scheduler,
        presentations: presentations,
        onMemoryDetailsSelected: selectedMemories.add,
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.pause')),
      );

      expect(find.byKey(const ValueKey('story-playback.resume')), findsOneWidget);
      expect(scheduler.activeTaskCount, 0);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.details')),
      );

      expect(selectedMemories.single.memory.id, memoryA.id);
      expect(find.byKey(const ValueKey('story-playback.resume')), findsOneWidget);
      expect(scheduler.activeTaskCount, 0);
    });
  });

  group('StoryPlaybackScreen failure and media handling', () {
    testWidgets('shouldRenderCameraFailureAndRetryThroughNotifier', (
      tester,
    ) async {
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
          ],
        presentations: presentations,
        onMemoryDetailsSelected: (_) {},
      );

      final failedRevision = presentations.last.cameraCommand!.revision;
      presentations.last.onCameraFailed(failedRevision);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-playback.camera-failure')),
        findsOneWidget,
      );
      expect(find.text('Map movement paused'), findsOneWidget);
      expect(find.textContaining('41.715'), findsNothing);
      expect(find.textContaining('MapLibre'), findsNothing);
      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('story-playback.details')), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-playback.retry-camera')),
      );

      expect(
        find.byKey(const ValueKey('story-playback.camera-failure')),
        findsNothing,
      );
      expect(presentations.last.cameraCommand?.revision, greaterThan(1));
    });

    testWidgets('shouldRenderNoPhotoStateWhenPreviewIsAbsent', (
      tester,
    ) async {
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
          ],
        presentations: presentations,
        onMemoryDetailsSelected: (_) {},
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-playback.no-photo')), findsOneWidget);
      expect(find.text('No photo'), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.details')), findsOneWidget);
    });

    testWidgets('shouldRenderSafePhotoFailureWithoutStoppingPlayback', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..displayFailure = const UnexpectedImageException();
      final scheduler = FakePlaybackScheduler();
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(
              memoryA,
              previewPhoto: previewPhoto(mediaId: 'media-a'),
            ),
          ],
        mediaRepository: mediaRepository,
        scheduler: scheduler,
        presentations: presentations,
        onMemoryDetailsSelected: (_) {},
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-playback.photo-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('story-playback.details')), findsOneWidget);
      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.textContaining('media-a'), findsNothing);

      scheduler.latest.fire();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-playback.finished')), findsOneWidget);
    });

    testWidgets('shouldNotEagerlyLoadDisplayForEverySnapshotMemory', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..displayResult = media_fixtures.validPngBytes;
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(
              memoryA,
              previewPhoto: previewPhoto(mediaId: 'media-a'),
            ),
            readModel(
              memoryB,
              previewPhoto: previewPhoto(mediaId: 'media-b'),
            ),
          ],
        mediaRepository: mediaRepository,
        presentations: presentations,
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(mediaRepository.getMediaCalls, 0);
      expect(mediaRepository.getThumbnailByPathCalls, 0);
      expect(mediaRepository.getDisplayByPathCalls, 1);
      expect(mediaRepository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-a/display',
      ]);
    });
  });

  group('StoryPlaybackScreen snapshot and responsiveness', () {
    testWidgets('shouldIgnoreSharedStoryMemoryMutationAfterStart', (
      tester,
    ) async {
      final presentations = <PlaybackMapPresentation>[];
      final container = await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(memoryA),
          ],
        presentations: presentations,
      );

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertAuthoritativeRead(readModel(memoryB));
      await tester.pumpAndSettle();

      expect(presentations.last.markers.length, 1);
      expect(presentations.last.route.hasRoute, isFalse);
      expect(find.text('1 / 1 memory'), findsOneWidget);
    });

    testWidgets('shouldRemainUsableOnSmallPhoneWithLargeText', (
      tester,
    ) async {
      setSurface(tester, const Size(320, 640));
      final presentations = <PlaybackMapPresentation>[];
      final longMemory = memory(
        id: 'long-memory',
        title: 'A long but visible playback title',
        description: List<String>.filled(20, 'long description').join(' '),
        placeName: 'A place with a slightly longer name',
      );

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(longMemory),
          ],
        presentations: presentations,
        textScaler: const TextScaler.linear(1.4),
      );

      presentations.last.onCameraArrived(
        presentations.last.cameraCommand!.revision,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-playback.memory-card')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('story-playback.controls')), findsNothing);
      expect(find.byKey(const ValueKey('story-playback.pause')), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.next')), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.close')), findsOneWidget);
    });

    testWidgets('shouldKeepVisibleDiagnosticsPrivate', (tester) async {
      final presentations = <PlaybackMapPresentation>[];

      await pumpPlaybackScreen(
        tester,
        FakeMemoryRepository()
          ..memoryReadModelsResult = <MemoryReadModel>[
            readModel(
              memory(
                id: 'private-memory-id',
                storyId: 'private-story-id',
                title: 'Visible memory title',
                latitude: 41.715123,
                longitude: 44.827456,
              ),
              previewPhoto: previewPhoto(mediaId: 'private-media-id'),
            ),
          ],
        storyId: 'private-story-id',
        presentations: presentations,
      );

      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-media-id'), findsNothing);
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.textContaining('41.715123'), findsNothing);
      expect(find.textContaining('44.827456'), findsNothing);
      expect(presentations.last.toString(), isNot(contains('private')));
      expect(presentations.last.toString(), isNot(contains('/api/v1/media')));
    });
  });
}

Future<ProviderContainer> pumpPlaybackScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
  String storyId = 'story-1',
  String? storyTitle,
  VoidCallback? onClose,
  FakePlaybackScheduler? scheduler,
  media_fixtures.FakeMediaRepository? mediaRepository,
  List<PlaybackMapPresentation>? presentations,
  ValueChanged<MemoryReadModel>? onMemoryDetailsSelected,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
      playbackSchedulerProvider.overrideWithValue(
        scheduler ?? FakePlaybackScheduler(),
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
        home: StoryPlaybackScreen(
          storyId: storyId,
          storyTitle: storyTitle,
          onClose: onClose ?? () {},
          onMemoryDetailsSelected: onMemoryDetailsSelected,
          mapBuilder: (context, presentation) {
            presentations?.add(presentation);
            return _FakePlaybackMap(presentation: presentation);
          },
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
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    OutlinedButton(:final onPressed) => onPressed,
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

MemoryReadModel readModel(
  Memory memory, {
  MemoryPhotoPreview? previewPhoto,
}) {
  return MemoryReadModel(memory: memory, previewPhoto: previewPhoto);
}

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

Memory memory({
  required String id,
  String storyId = 'story-1',
  String title = 'Sunrise picnic',
  String? description = 'Visible description',
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

final Memory memoryA = memory(id: 'memory-a', day: 9, createdHour: 10);
final Memory memoryB = memory(id: 'memory-b', day: 20, createdHour: 11);

final class _FakePlaybackMap extends StatelessWidget {
  const _FakePlaybackMap({
    required this.presentation,
  });

  final PlaybackMapPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('story-playback.fake-map'),
      color: const Color(0xFFEFF3F7),
      child: Column(
        children: [
          Text(
            'markers:${presentation.markers.length}',
            key: const ValueKey('story-playback.fake-map.marker-count'),
          ),
          Text(
            'current:${presentation.currentIndex ?? -1}',
            key: const ValueKey('story-playback.fake-map.current-index'),
          ),
          Text(
            presentation.cameraCommand == null
                ? 'camera:none'
                : 'camera:${presentation.cameraCommand!.revision}',
            key: const ValueKey('story-playback.fake-map.camera'),
          ),
        ],
      ),
    );
  }
}

final class FakePlaybackScheduler implements PlaybackScheduler {
  final List<FakePlaybackScheduledTask> tasks = <FakePlaybackScheduledTask>[];

  int get activeTaskCount => tasks.where((task) => task.isActive).length;

  FakePlaybackScheduledTask get latest => tasks.last;

  @override
  PlaybackScheduledTask schedule(
    Duration delay,
    void Function() callback,
  ) {
    final task = FakePlaybackScheduledTask(
      delay: delay,
      callback: callback,
    );
    tasks.add(task);
    return task;
  }
}

final class FakePlaybackScheduledTask implements PlaybackScheduledTask {
  FakePlaybackScheduledTask({
    required this.delay,
    required this.callback,
  });

  final Duration delay;
  final void Function() callback;
  bool isCanceled = false;
  bool hasFired = false;

  bool get isActive => !isCanceled && !hasFired;

  void fire() {
    hasFired = true;
    callback();
  }

  @override
  void cancel() {
    isCanceled = true;
  }
}

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<List<MemoryReadModel>>? getCompleter;
  List<MemoryReadModel> memoryReadModelsResult = <MemoryReadModel>[];
  final List<List<MemoryReadModel>> memoryReadModelsResults =
      <List<MemoryReadModel>>[];
  final List<Object> getFailures = <Object>[];
  final List<String> receivedStoryIds = <String>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    receivedStoryIds.add(storyId);

    final completer = getCompleter;
    if (completer != null) {
      getCompleter = null;
      return completer.future;
    }

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    if (memoryReadModelsResults.isNotEmpty) {
      return memoryReadModelsResults.removeAt(0);
    }

    return memoryReadModelsResult;
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    return readModel(memoryA);
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

final class UnexpectedImageException implements Exception {
  const UnexpectedImageException();
}
