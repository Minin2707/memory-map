import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
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
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_provider.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';
import 'package:memory_map/features/playback/application/playback_media_prefetcher.dart';
import 'package:memory_map/features/playback/application/playback_scheduler.dart';
import 'package:memory_map/features/playback/application/playback_scheduler_provider.dart';
import 'package:memory_map/features/playback/application/playback_session_state.dart';
import 'package:memory_map/features/playback/application/story_playback_provider.dart';
import 'package:memory_map/features/playback/domain/playback_phase.dart';
import 'package:memory_map/features/playback/domain/playback_status.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';

void main() {
  group('StoryPlaybackNotifier provider initialization', () {
    test('shouldStartImmediatelyFromLoadedSharedMemoriesWithoutDuplicateGet',
        () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryB),
          readModel(memoryA),
        ];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider('story-1').future);

      final state = container.read(storyPlaybackProvider('story-1'));

      expect(state.requirePlayback.status, PlaybackStatus.playing);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
      expect(state.requirePlayback.snapshot.map((item) => item.memory.id), [
        memoryA.id,
        memoryB.id,
      ]);
      expect(state.requirePlayback.cameraCommand?.revision, 1);
      expect(repository.getMemoriesCalls, 1);
      expect(repository.operations, <String>['getMemories']);
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldWaitWhileSharedMemoriesAreLoading', () async {
      final completer = Completer<List<MemoryReadModel>>();
      final repository = FakeMemoryRepository()..getCompleter = completer;
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);

      expect(
        container.read(storyPlaybackProvider('story-1')),
        PlaybackSessionState.loading(),
      );
      expect(repository.getMemoriesCalls, 1);

      completer.complete(<MemoryReadModel>[readModel(memoryA)]);
      await container.read(storyMemoriesProvider('story-1').future);
      await pumpEventQueue();

      expect(
        container.read(storyPlaybackProvider('story-1')).requirePlayback
            .currentMemory
            ?.memory
            .id,
        memoryA.id,
      );
      expect(repository.getMemoriesCalls, 1);
    });

    test('shouldExposeLoadedEmptyAsSafeIdleSession', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = const <MemoryReadModel>[];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);

      final state = await waitForPlaybackSession(container, 'story-1');

      expect(state.requirePlayback.status, PlaybackStatus.idle);
      expect(state.requirePlayback.snapshot, isEmpty);
      expect(state.requirePlayback.cameraCommand, isNull);
      expect(state.hasLoadFailure, isFalse);
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldExposeKnownInitialFailureSafely', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        );
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);

      final state = await waitForPlaybackSession(container, 'story-1');

      expect(state.loadFailure, const MemoryStoryUnavailable());
      expect(state.hasSession, isFalse);
      expect(state.toString(), isNot(contains('story-1')));
      expect(state.toString(), isNot(contains('Dio')));
    });

    test('shouldConvertUnexpectedAsyncErrorToSafeFailure', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(const UnexpectedMemoryException());
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);

      final state = await waitForPlaybackSession(container, 'story-1');

      expect(state.loadFailure, const UnknownMemoryFailure());
      expect(state.toString(), isNot(contains('UnexpectedMemoryException')));
    });
  });

  group('StoryPlaybackNotifier audio session initialization', () {
    test('shouldResolveFreshSoundtrackOnceWhenVisualPlaybackStarts', () async {
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..results.add(
          StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
        );
      final audioController = FakePlaybackAudioController();
      final container = createContainer(
        memoryRepository,
        FakePlaybackScheduler(),
        useRealAudioOrchestrator: true,
        soundtrackRepository: soundtrackRepository,
        audioController: audioController,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      final state = await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(state.requirePlayback.status, PlaybackStatus.playing);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
      expect(soundtrackRepository.operations, <String>['get:story-1']);
      expect(audioController.prepareStoryIds, <String>['story-1']);
    });

    test('shouldNotWaitForSoundtrackResolutionBeforeStartingVisualPlayback',
        () async {
      final soundtrackCompleter = Completer<StorySoundtrack>();
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..completers.add(soundtrackCompleter);
      final audioController = FakePlaybackAudioController();
      final container = createContainer(
        memoryRepository,
        FakePlaybackScheduler(),
        useRealAudioOrchestrator: true,
        soundtrackRepository: soundtrackRepository,
        audioController: audioController,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      final state = await waitForPlaybackSession(container, 'story-1');

      expect(state.requirePlayback.status, PlaybackStatus.playing);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
      expect(soundtrackRepository.operations, <String>['get:story-1']);
      expect(audioController.prepareStoryIds, isEmpty);

      soundtrackCompleter.complete(StorySoundtrack.noMusic());
      await pumpEventQueue();
    });

    test('shouldKeepVisualPlaybackWhenSoundtrackResolutionFails', () async {
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..failures.add(const PrivateMusicException());
      final audioController = FakePlaybackAudioController();
      final container = createContainer(
        memoryRepository,
        FakePlaybackScheduler(),
        useRealAudioOrchestrator: true,
        soundtrackRepository: soundtrackRepository,
        audioController: audioController,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      final state = await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(state.requirePlayback.status, PlaybackStatus.playing);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
      expect(soundtrackRepository.operations, <String>['get:story-1']);
      expect(audioController.prepareStoryIds, isEmpty);
    });

    test('shouldKeepVisualPlaybackWhenAudioPrepareFails', () async {
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..results.add(
          StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
        );
      final audioController = FakePlaybackAudioController()
        ..prepareFailure = const PrivateAudioException();
      final container = createContainer(
        memoryRepository,
        FakePlaybackScheduler(),
        useRealAudioOrchestrator: true,
        soundtrackRepository: soundtrackRepository,
        audioController: audioController,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      final state = await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(state.requirePlayback.status, PlaybackStatus.playing);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
      expect(soundtrackRepository.operations, <String>['get:story-1']);
      expect(audioController.prepareStoryIds, <String>['story-1']);
    });

    test('shouldNotResolveSoundtrackPerMemoryTransition', () async {
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB),
        ];
      final soundtrackRepository = FakeStorySoundtrackRepository()
        ..results.add(
          StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
        );
      final audioController = FakePlaybackAudioController();
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(
        memoryRepository,
        scheduler,
        useRealAudioOrchestrator: true,
        soundtrackRepository: soundtrackRepository,
        audioController: audioController,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      scheduler.latest.fire();
      notifier.next();
      await pumpEventQueue();

      expect(soundtrackRepository.operations, <String>['get:story-1']);
      expect(audioController.prepareStoryIds, <String>['story-1']);
      expect(playback(container).currentMemory?.memory.id, memoryB.id);
    });

    test('shouldNotResolveSoundtrackForEmptyVisualSession', () async {
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelsResult = const <MemoryReadModel>[];
      final soundtrackRepository = FakeStorySoundtrackRepository();
      final audioController = FakePlaybackAudioController();
      final container = createContainer(
        memoryRepository,
        FakePlaybackScheduler(),
        useRealAudioOrchestrator: true,
        soundtrackRepository: soundtrackRepository,
        audioController: audioController,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      final state = await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(state.requirePlayback.status, PlaybackStatus.idle);
      expect(soundtrackRepository.operations, isEmpty);
      expect(audioController.prepareStoryIds, isEmpty);
    });

    test('shouldSignalAudioPlayingIntentBeforeStartingAudioSession', () async {
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final container = createContainer(
        memoryRepository,
        FakePlaybackScheduler(),
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(
        audioOrchestrator.operations
            .where((operation) => operation != 'invalidateSession')
            .toList(),
        <String>[
          'playbackStarted',
          'startSession:story-1',
        ],
      );
    });
  });

  group('StoryPlaybackNotifier audio lifecycle mapping', () {
    test('shouldMapPauseAndResumeMovingToAudioPauseAndResume', () async {
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        FakePlaybackScheduler(),
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      audioOrchestrator.operations.clear();
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.pause();
      notifier.resume();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, <String>['pause', 'resume']);
      expect(playback(container).status, PlaybackStatus.playing);
      expect(playback(container).phase, PlaybackPhase.moving);
    });

    test('shouldMapPauseAndResumePresentingToAudioPauseAndResume', () async {
      final scheduler = FakePlaybackScheduler();
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        scheduler,
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      audioOrchestrator.operations.clear();

      notifier.pause();
      notifier.resume();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, <String>['pause', 'resume']);
      expect(playback(container).status, PlaybackStatus.playing);
      expect(playback(container).phase, PlaybackPhase.presenting);
      expect(scheduler.activeTaskCount, 1);
    });

    test('shouldPauseAudioOnCameraFailureAndResumeAfterRetry', () async {
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        FakePlaybackScheduler(),
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final revision = playback(container).cameraRevision;
      audioOrchestrator.operations.clear();

      notifier.cameraFailed(revision);
      notifier.retryCamera();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, <String>[
        'cameraFailed',
        'resume',
      ]);
      expect(container.read(storyPlaybackProvider('story-1')).hasCameraFailure,
          isFalse);
      expect(playback(container).status, PlaybackStatus.playing);
      expect(playback(container).phase, PlaybackPhase.moving);
    });

    test('shouldStopAudioWhenVisualPlaybackFinishesFromTimer', () async {
      final scheduler = FakePlaybackScheduler();
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        scheduler,
        memories: [readModel(memoryA)],
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      audioOrchestrator.operations.clear();

      scheduler.latest.fire();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, <String>['finish']);
      expect(playback(container).status, PlaybackStatus.finished);
    });

    test('shouldStopAudioWhenNextFinishesLastPresentingMemory', () async {
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        FakePlaybackScheduler(),
        memories: [readModel(memoryA)],
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      audioOrchestrator.operations.clear();

      notifier.next();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, <String>['finish']);
      expect(playback(container).status, PlaybackStatus.finished);
    });

    test('shouldReplayAudioWithoutStartingNewSoundtrackSession', () async {
      final scheduler = FakePlaybackScheduler();
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        scheduler,
        memories: [readModel(memoryA)],
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      scheduler.latest.fire();
      audioOrchestrator.operations.clear();

      notifier.replay();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, <String>['replay']);
      expect(playback(container).status, PlaybackStatus.playing);
      expect(playback(container).phase, PlaybackPhase.moving);
    });

    test('shouldCloseAudioOnStop', () async {
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        FakePlaybackScheduler(),
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      audioOrchestrator.operations.clear();

      notifier.stop();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, <String>['close']);
      expect(playback(container).status, PlaybackStatus.idle);
    });

    test('shouldNotRestartAudioOnNextOrPreviousMemoryNavigation', () async {
      final audioOrchestrator = FakePlaybackAudioSessionOrchestrator();
      final container = await readyContainer(
        FakePlaybackScheduler(),
        memories: [readModel(memoryA), readModel(memoryB), readModel(memoryC)],
        audioOrchestrator: audioOrchestrator,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      audioOrchestrator.operations.clear();

      notifier.next();
      notifier.previous();
      await pumpEventQueue();

      expect(audioOrchestrator.operations, isEmpty);
      expect(playback(container).currentMemory?.memory.id, memoryA.id);
    });
  });

  group('StoryPlaybackNotifier snapshot stability', () {
    test('shouldIgnoreSharedCreateAfterStart', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB),
        ];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertAuthoritativeRead(readModel(memoryC));

      expect(playback(container).snapshot.map((item) => item.memory.id), [
        memoryA.id,
        memoryB.id,
      ]);
      expect(repository.getMemoriesCalls, 1);
    });

    test('shouldIgnoreSharedDeleteAfterStart', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB),
        ];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .removeMemoryById(memoryA.id);

      expect(playback(container).snapshot.map((item) => item.memory.id), [
        memoryA.id,
        memoryB.id,
      ]);
    });

    test('shouldIgnoreSharedEditAfterStart', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertAuthoritativeRead(readModel(memory(id: memoryA.id, title: 'New')));

      expect(playback(container).snapshot.single.memory.title, memoryA.title);
    });

    test('shouldIgnoreSharedPreviewReplacementAndNullAfterStart', () async {
      final oldPreview = previewPhoto(mediaId: 'media-old');
      final newPreview = previewPhoto(mediaId: 'media-new');
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA, previewPhoto: oldPreview),
        ];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');

      container.read(storyMemoriesProvider('story-1').notifier)
        ..upsertAuthoritativeRead(readModel(memoryA, previewPhoto: newPreview))
        ..upsertAuthoritativeRead(readModel(memoryA));

      expect(playback(container).snapshot.single.previewPhoto, same(oldPreview));
    });

    test('shouldTreatEmptyLoadedSnapshotAsCaptured', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = const <MemoryReadModel>[];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertAuthoritativeRead(readModel(memoryA));

      expect(playback(container).snapshot, isEmpty);
      expect(playback(container).status, PlaybackStatus.idle);
    });

    test('shouldCaptureFreshSnapshotAfterProviderReEntry', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB),
        ];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      final subscription = container.listen(
        storyPlaybackProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      await waitForPlaybackSession(container, 'story-1');

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertAuthoritativeRead(readModel(memoryC));
      subscription.close();
      await pumpEventQueue();

      final reentered = await waitForPlaybackSession(container, 'story-1');

      expect(reentered.requirePlayback.snapshot.map((item) => item.memory.id), [
        memoryA.id,
        memoryB.id,
        memoryC.id,
      ]);
      expect(repository.getMemoriesCalls, 1);
    });
  });

  group('StoryPlaybackNotifier timer orchestration', () {
    test('shouldScheduleOneTimerOnlyAfterValidCameraArrival', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);

      expect(scheduler.activeTaskCount, 0);

      final command = playback(container).cameraCommand!;
      container
          .read(storyPlaybackProvider('story-1').notifier)
          .cameraArrived(command.revision);

      expect(scheduler.activeTaskCount, 1);
      expect(scheduler.latest.delay, const Duration(seconds: 5));
    });

    test('shouldKeepTimerWhenSamePresentationRevisionIsObservedAgain', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.cameraArrived(playback(container).cameraRevision);
      final firstTask = scheduler.latest;
      notifier.cameraArrived(playback(container).cameraRevision);

      expect(scheduler.tasks.length, 1);
      expect(scheduler.latest, same(firstTask));
    });

    test('shouldDismissPresentationBeforeAdvancingToNextMoving', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      final presentationRevision = playback(container).presentationRevision;

      scheduler.latest.fire();

      expect(playback(container).phase, PlaybackPhase.dismissing);
      expect(playback(container).currentMemory?.memory.id, memoryA.id);
      expect(playback(container).cameraCommand, isNull);
      expect(scheduler.activeTaskCount, 0);

      notifier.presentationDismissed(presentationRevision);

      expect(playback(container).phase, PlaybackPhase.moving);
      expect(playback(container).currentMemory?.memory.id, memoryB.id);
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldFinishAfterLastPresentationTimerFires', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(
        scheduler,
        memories: [readModel(memoryA)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);

      scheduler.latest.fire();

      expect(playback(container).status, PlaybackStatus.finished);
      expect(playback(container).cameraCommand, isNull);
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldCancelTimerOnPauseNextPreviousReplayStopAndDispose', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(
        scheduler,
        memories: [readModel(memoryA), readModel(memoryB), readModel(memoryC)],
      );
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.cameraArrived(playback(container).cameraRevision);
      notifier.pause();
      expect(scheduler.tasks.last.isCanceled, isTrue);

      notifier.resume();
      notifier.next();
      expect(scheduler.activeTaskCount, 0);

      notifier.cameraArrived(playback(container).cameraRevision);
      notifier.previous();
      expect(scheduler.tasks.last.isCanceled, isTrue);

      notifier.cameraArrived(playback(container).cameraRevision);
      notifier.replay();
      expect(scheduler.tasks.last.isCanceled, isTrue);

      notifier.cameraArrived(playback(container).cameraRevision);
      notifier.stop();
      expect(scheduler.tasks.last.isCanceled, isTrue);

      notifier.replay();
      container.dispose();
      expect(scheduler.tasks.where((task) => task.isActive), isEmpty);
    });

    test('shouldIgnoreStaleTimerAfterNextPauseResumeAndReplay', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(
        scheduler,
        memories: [readModel(memoryA), readModel(memoryB), readModel(memoryC)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      final staleFirst = scheduler.latest;

      notifier.next();
      staleFirst.fire();
      expect(playback(container).currentMemory?.memory.id, memoryB.id);
      expect(playback(container).phase, PlaybackPhase.moving);

      notifier.cameraArrived(playback(container).cameraRevision);
      final staleSecond = scheduler.latest;
      notifier.pause();
      notifier.resume();
      staleSecond.fire();
      expect(playback(container).currentMemory?.memory.id, memoryB.id);
      expect(playback(container).phase, PlaybackPhase.presenting);

      scheduler.latest.fire();
      notifier.presentationDismissed(playback(container).presentationRevision);
      notifier.cameraArrived(playback(container).cameraRevision);
      final staleThird = scheduler.latest;
      notifier.replay();
      staleThird.fire();
      expect(playback(container).currentMemory?.memory.id, memoryA.id);
      expect(playback(container).phase, PlaybackPhase.moving);
    });
  });

  group('StoryPlaybackNotifier camera and controls', () {
    test('shouldExposeRecoverableCameraFailureWithoutAdvancingOrTimer', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final command = playback(container).cameraCommand!;

      notifier.cameraFailed(command.revision);

      final state = container.read(storyPlaybackProvider('story-1'));
      expect(state.hasCameraFailure, isTrue);
      expect(state.cameraFailure?.revision, command.revision);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
      expect(state.requirePlayback.currentMemory?.memory.id, memoryA.id);
      expect(state.requirePlayback.cameraCommand, command);
      expect(scheduler.activeTaskCount, 0);

      notifier.cameraArrived(command.revision);
      notifier.presentationElapsed(command.revision);

      expect(playback(container).phase, PlaybackPhase.moving);
      expect(playback(container).currentMemory?.memory.id, memoryA.id);
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldIgnoreStaleCameraFailure', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final staleRevision = playback(container).cameraRevision;

      notifier.next();
      notifier.cameraFailed(staleRevision);

      final state = container.read(storyPlaybackProvider('story-1'));
      expect(state.hasCameraFailure, isFalse);
      expect(playback(container).currentMemory?.memory.id, memoryB.id);
      expect(playback(container).phase, PlaybackPhase.moving);
    });

    test('shouldIgnoreCameraFailureWhenPaused', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final revision = playback(container).cameraRevision;

      notifier.pause();
      notifier.cameraFailed(revision);

      final state = container.read(storyPlaybackProvider('story-1'));
      expect(state.hasCameraFailure, isFalse);
      expect(state.requirePlayback.status, PlaybackStatus.paused);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
    });

    test('shouldRetryCameraFailureToSameMemoryWithFreshRevision', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final failedCommand = playback(container).cameraCommand!;

      notifier.cameraFailed(failedCommand.revision);
      notifier.retryCamera();

      final retried = playback(container);
      expect(container.read(storyPlaybackProvider('story-1')).hasCameraFailure,
          isFalse);
      expect(retried.phase, PlaybackPhase.moving);
      expect(retried.currentMemory?.memory.id, memoryA.id);
      expect(retried.cameraCommand?.revision,
          greaterThan(failedCommand.revision));
      expect(retried.cameraCommand?.target, failedCommand.target);
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldEnterPresentingNormallyAfterSuccessfulRetryArrival', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final failedCommand = playback(container).cameraCommand!;

      notifier.cameraFailed(failedCommand.revision);
      notifier.retryCamera();
      final retryRevision = playback(container).cameraRevision;
      notifier.cameraArrived(failedCommand.revision);
      notifier.cameraArrived(retryRevision);

      expect(playback(container).phase, PlaybackPhase.presenting);
      expect(scheduler.activeTaskCount, 1);
    });

    test('shouldAllowManualNavigationToRecoverFromCameraFailure', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.cameraFailed(playback(container).cameraRevision);
      notifier.next();

      final state = container.read(storyPlaybackProvider('story-1'));
      expect(state.hasCameraFailure, isFalse);
      expect(state.requirePlayback.currentMemory?.memory.id, memoryB.id);
      expect(state.requirePlayback.phase, PlaybackPhase.moving);
      expect(state.requirePlayback.cameraCommand?.revision, greaterThan(1));
    });

    test('shouldIgnoreStalePausedAndStoppedCameraArrival', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final originalRevision = playback(container).cameraRevision;

      notifier.next();
      notifier.cameraArrived(originalRevision);
      expect(scheduler.activeTaskCount, 0);
      expect(playback(container).phase, PlaybackPhase.moving);

      notifier.pause();
      notifier.cameraArrived(playback(container).cameraRevision);
      expect(scheduler.activeTaskCount, 0);

      notifier.stop();
      notifier.cameraArrived(playback(container).cameraRevision);
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldResumeMovingWithFreshCameraRevisionAndNoTimer', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      final originalCommand = playback(container).cameraCommand!;

      notifier.pause();
      notifier.cameraArrived(originalCommand.revision);
      notifier.resume();

      expect(playback(container).status, PlaybackStatus.playing);
      expect(playback(container).phase, PlaybackPhase.moving);
      expect(playback(container).currentMemory?.memory.id, memoryA.id);
      expect(playback(container).cameraCommand?.revision,
          greaterThan(originalCommand.revision));
      expect(scheduler.activeTaskCount, 0);
    });

    test('shouldResumePresentingWithFreshFullTimer', () async {
      final scheduler = FakePlaybackScheduler();
      final container = await readyContainer(scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      final oldTask = scheduler.latest;
      final oldRevision = playback(container).presentationRevision;

      notifier.pause();
      notifier.resume();

      expect(oldTask.isCanceled, isTrue);
      expect(playback(container).presentationRevision, greaterThan(oldRevision));
      expect(scheduler.latest.delay, const Duration(seconds: 5));
      oldTask.fire();
      expect(playback(container).phase, PlaybackPhase.presenting);
    });

    test('shouldReplaySameSnapshotWithoutRepositoryCall', () async {
      final scheduler = FakePlaybackScheduler();
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[readModel(memoryA)];
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);
      notifier.cameraArrived(playback(container).cameraRevision);
      scheduler.latest.fire();

      notifier.replay();

      expect(repository.getMemoriesCalls, 1);
      expect(playback(container).status, PlaybackStatus.playing);
      expect(playback(container).phase, PlaybackPhase.moving);
      expect(playback(container).snapshot.map((item) => item.memory.id), [
        memoryA.id,
      ]);
      expect(scheduler.activeTaskCount, 0);
    });
  });

  group('StoryPlaybackNotifier media prefetch', () {
    test('shouldStartNextDisplayPrefetchWhenPlaybackStarts', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher();
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB, previewPhoto: previewPhoto(mediaId: 'media-b')),
        ];
      final container = createContainer(
        repository,
        FakePlaybackScheduler(),
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(mediaPrefetcher.displayPaths, <String>[
        '/api/v1/media/media-b/display',
      ]);
    });

    test('shouldNotPrefetchWhenThereIsNoNextMemory', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher();
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA, previewPhoto: previewPhoto(mediaId: 'media-a')),
        ];
      final container = createContainer(
        repository,
        FakePlaybackScheduler(),
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(mediaPrefetcher.displayPaths, isEmpty);
    });

    test('shouldNotPrefetchWhenNextMemoryHasNoPreviewPhoto', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher();
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(memoryA, previewPhoto: previewPhoto(mediaId: 'media-a')),
          readModel(memoryB),
        ];
      final container = createContainer(
        repository,
        FakePlaybackScheduler(),
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');

      await waitForPlaybackSession(container, 'story-1');
      await pumpEventQueue();

      expect(mediaPrefetcher.displayPaths, isEmpty);
    });

    test('shouldNotAwaitPrefetchBeforePlaybackProgression', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher()
        ..pendingCompleters.add(Completer<void>());
      final container = await readyContainer(
        FakePlaybackScheduler(),
        memories: <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB, previewPhoto: previewPhoto(mediaId: 'media-b')),
          readModel(memoryC, previewPhoto: previewPhoto(mediaId: 'media-c')),
        ],
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.next();

      expect(playback(container).currentMemory?.memory.id, memoryB.id);
      expect(playback(container).phase, PlaybackPhase.moving);
    });

    test('shouldKeepPlaybackStateWhenPrefetchFails', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher()
        ..failures.add(Object());
      final container = await readyContainer(
        FakePlaybackScheduler(),
        memories: <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB, previewPhoto: previewPhoto(mediaId: 'media-b')),
        ],
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      await pumpEventQueue();

      expect(playback(container).status, PlaybackStatus.playing);
      expect(playback(container).currentMemory?.memory.id, memoryA.id);
    });

    test('shouldUseNextOnlyLookaheadAcrossRapidNextAndPrevious', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher();
      final container = await readyContainer(
        FakePlaybackScheduler(),
        memories: <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB, previewPhoto: previewPhoto(mediaId: 'media-b')),
          readModel(memoryC, previewPhoto: previewPhoto(mediaId: 'media-c')),
        ],
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.next();
      notifier.previous();
      await pumpEventQueue();

      expect(mediaPrefetcher.displayPaths, <String>[
        '/api/v1/media/media-b/display',
        '/api/v1/media/media-c/display',
        '/api/v1/media/media-b/display',
      ]);
      expect(playback(container).currentMemory?.memory.id, memoryA.id);
    });

    test('shouldAllowActivePrefetchToFinishWhilePaused', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher();
      final container = await readyContainer(
        FakePlaybackScheduler(),
        memories: <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB, previewPhoto: previewPhoto(mediaId: 'media-b')),
        ],
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.pause();
      await pumpEventQueue();

      expect(playback(container).status, PlaybackStatus.paused);
      expect(mediaPrefetcher.displayPaths, <String>[
        '/api/v1/media/media-b/display',
      ]);
    });

    test('shouldResetPrefetchGuardOnReplay', () async {
      final scheduler = FakePlaybackScheduler();
      final mediaPrefetcher = FakePlaybackMediaPrefetcher();
      final container = await readyContainer(
        scheduler,
        memories: <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB, previewPhoto: previewPhoto(mediaId: 'media-b')),
        ],
        mediaPrefetcher: mediaPrefetcher,
      );
      addTearDown(container.dispose);
      final notifier = container.read(storyPlaybackProvider('story-1').notifier);

      notifier.cameraArrived(playback(container).cameraRevision);
      scheduler.latest.fire();
      notifier.replay();
      await pumpEventQueue();

      expect(mediaPrefetcher.displayPaths, <String>[
        '/api/v1/media/media-b/display',
        '/api/v1/media/media-b/display',
      ]);
    });

    test('shouldRemainSafeWhenDisposedDuringActivePrefetch', () async {
      final mediaPrefetcher = FakePlaybackMediaPrefetcher()
        ..pendingCompleters.add(Completer<void>());
      final container = await readyContainer(
        FakePlaybackScheduler(),
        memories: <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB, previewPhoto: previewPhoto(mediaId: 'media-b')),
        ],
        mediaPrefetcher: mediaPrefetcher,
      );
      final activePrefetch = mediaPrefetcher.startedCompleters.single;

      container.dispose();
      activePrefetch.complete();
      await pumpEventQueue();

      expect(mediaPrefetcher.displayPaths, <String>[
        '/api/v1/media/media-b/display',
      ]);
    });
  });

  group('StoryPlaybackNotifier retry, isolation, and privacy', () {
    test('shouldRetryInitialFailureAndStartOnceAfterSuccess', () async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryNetworkUnavailable()),
        )
        ..memoryReadModelsResults.add(<MemoryReadModel>[readModel(memoryA)]);
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-1');

      await container.read(storyPlaybackProvider('story-1').notifier).retry();

      expect(repository.getMemoriesCalls, 2);
      expect(playback(container).currentMemory?.memory.id, memoryA.id);

      container
          .read(storyMemoriesProvider('story-1').notifier)
          .upsertAuthoritativeRead(readModel(memoryB));

      expect(playback(container).snapshot.map((item) => item.memory.id), [
        memoryA.id,
      ]);
    });

    test('shouldKeepIndependentFamilySessionsAndTimers', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResults.add(<MemoryReadModel>[readModel(memoryA)])
        ..memoryReadModelsResults.add(<MemoryReadModel>[
          readModel(memory(id: 'story-2-memory', storyId: 'story-2')),
        ]);
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'story-1');
      holdPlaybackSession(container, 'story-2');

      await waitForPlaybackSession(container, 'story-1');
      await waitForPlaybackSession(container, 'story-2');
      container
          .read(storyPlaybackProvider('story-1').notifier)
          .cameraArrived(
            container
                .read(storyPlaybackProvider('story-1'))
                .requirePlayback
                .cameraRevision,
          );

      expect(
        container
            .read(storyPlaybackProvider('story-1'))
            .requirePlayback
            .isPresenting,
        isTrue,
      );
      expect(
        container
            .read(storyPlaybackProvider('story-2'))
            .requirePlayback
            .isMoving,
        isTrue,
      );
      expect(repository.receivedStoryIds, <String>['story-1', 'story-2']);
      expect(scheduler.activeTaskCount, 1);
    });

    test('shouldKeepDiagnosticsPrivate', () async {
      final repository = FakeMemoryRepository()
        ..memoryReadModelsResult = <MemoryReadModel>[
          readModel(
            memory(
              id: 'private-memory-id',
              storyId: 'private-story-id',
              title: 'Private title',
              description: 'Private description',
              placeName: 'Private place',
              latitude: 41.715123,
              longitude: 44.827456,
            ),
            previewPhoto: previewPhoto(mediaId: 'private-media-id'),
          ),
        ];
      final scheduler = FakePlaybackScheduler();
      final container = createContainer(repository, scheduler);
      addTearDown(container.dispose);
      holdPlaybackSession(container, 'private-story-id');
      await waitForPlaybackSession(container, 'private-story-id');

      final text = container
          .read(storyPlaybackProvider('private-story-id'))
          .toString();

      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Private place')));
      expect(text, isNot(contains('private-media-id')));
      expect(text, isNot(contains('/api/v1/media')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(scheduler.toString(), isNot(contains('private')));
    });
  });
}

ProviderContainer createContainer(
  FakeMemoryRepository repository,
  FakePlaybackScheduler scheduler, {
  bool useRealAudioOrchestrator = false,
  FakeStorySoundtrackRepository? soundtrackRepository,
  FakePlaybackAudioController? audioController,
  FakePlaybackAudioSessionOrchestrator? audioOrchestrator,
  FakePlaybackMediaPrefetcher? mediaPrefetcher,
}) {
  return ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
      playbackSchedulerProvider.overrideWithValue(scheduler),
      playbackMediaPrefetcherProvider.overrideWithValue(
        mediaPrefetcher ?? FakePlaybackMediaPrefetcher(),
      ),
      if (useRealAudioOrchestrator) ...[
        storySoundtrackRepositoryProvider.overrideWithValue(
          soundtrackRepository ?? FakeStorySoundtrackRepository(),
        ),
        playbackAudioControllerFactoryProvider.overrideWithValue(
          (_) => audioController ?? FakePlaybackAudioController(),
        ),
      ] else
        playbackAudioOrchestratorProvider.overrideWith(
          (ref, storyId) =>
              audioOrchestrator ?? FakePlaybackAudioSessionOrchestrator(),
        ),
    ],
  );
}

Future<ProviderContainer> readyContainer(
  FakePlaybackScheduler scheduler, {
  List<MemoryReadModel>? memories,
  FakePlaybackAudioSessionOrchestrator? audioOrchestrator,
  FakePlaybackMediaPrefetcher? mediaPrefetcher,
}) async {
  final repository = FakeMemoryRepository()
    ..memoryReadModelsResult = memories ??
        <MemoryReadModel>[
          readModel(memoryA),
          readModel(memoryB),
        ];
  final container = createContainer(
    repository,
    scheduler,
    audioOrchestrator: audioOrchestrator,
    mediaPrefetcher: mediaPrefetcher,
  );
  holdPlaybackSession(container, 'story-1');
  await waitForPlaybackSession(container, 'story-1');
  return container;
}

void holdPlaybackSession(ProviderContainer container, String storyId) {
  final subscription = container.listen(
    storyPlaybackProvider(storyId),
    (previous, next) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
}

Future<PlaybackSessionState> waitForPlaybackSession(
  ProviderContainer container,
  String storyId,
) async {
  final completer = Completer<PlaybackSessionState>();
  late final ProviderSubscription<PlaybackSessionState> subscription;
  subscription = container.listen(
    storyPlaybackProvider(storyId),
    (previous, next) {
      if (!next.isLoading && !completer.isCompleted) {
        completer.complete(next);
      }
    },
    fireImmediately: true,
  );

  final state = await completer.future;
  subscription.close();
  return state;
}

StoryPlaybackState playback(ProviderContainer container) {
  return container.read(storyPlaybackProvider('story-1')).requirePlayback;
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
  id: 'memory-a',
  title: 'A',
  day: 10,
);

final Memory memoryB = memory(
  id: 'memory-b',
  title: 'B',
  day: 20,
);

final Memory memoryC = memory(
  id: 'memory-c',
  title: 'C',
  day: 30,
);

final MusicTrack trackA = MusicTrack(
  id: 'track-a',
  title: 'Autumn Leaves',
  artist: 'LofCosmos',
  durationSeconds: 270,
);

final class FakePlaybackMediaPrefetcher implements PlaybackMediaPrefetcher {
  final List<String> displayPaths = <String>[];
  final List<Object> failures = <Object>[];
  final List<Completer<void>> pendingCompleters = <Completer<void>>[];
  final List<Completer<void>> startedCompleters = <Completer<void>>[];

  @override
  Future<void> prefetchNext(StoryPlaybackState playback) {
    final displayPath = nextPlaybackDisplayPath(playback);
    if (displayPath == null) {
      return Future<void>.value();
    }

    displayPaths.add(displayPath);
    if (failures.isNotEmpty) {
      failures.removeAt(0);
      return Future<void>.value();
    }

    if (pendingCompleters.isNotEmpty) {
      final completer = pendingCompleters.removeAt(0);
      startedCompleters.add(completer);
      return completer.future;
    }

    return Future<void>.value();
  }
}

final class FakePlaybackAudioSessionOrchestrator
    implements PlaybackAudioSessionOrchestrator {
  final List<String> startedStoryIds = <String>[];
  final List<String> operations = <String>[];
  int invalidateCalls = 0;

  @override
  PlaybackAudioSessionStatus status = PlaybackAudioSessionStatus.idle;

  @override
  Future<void> cameraFailed() async {
    operations.add('cameraFailed');
  }

  @override
  Future<void> close() async {
    operations.add('close');
  }

  @override
  Future<void> finish() async {
    operations.add('finish');
  }

  @override
  Future<void> startSession({required String storyId}) async {
    operations.add('startSession:$storyId');
    startedStoryIds.add(storyId);
  }

  @override
  Future<void> pause() async {
    operations.add('pause');
  }

  @override
  Future<void> playbackStarted() async {
    operations.add('playbackStarted');
  }

  @override
  Future<void> replay() async {
    operations.add('replay');
  }

  @override
  Future<void> resume() async {
    operations.add('resume');
  }

  @override
  void invalidateSession() {
    operations.add('invalidateSession');
    invalidateCalls++;
  }
}

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  final List<String> operations = <String>[];
  final List<Object> failures = <Object>[];
  final List<StorySoundtrack> results = <StorySoundtrack>[];
  final List<Completer<StorySoundtrack>> completers =
      <Completer<StorySoundtrack>>[];

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) {
    operations.add('get:$storyId');
    if (failures.isNotEmpty) {
      throw failures.removeAt(0);
    }

    if (completers.isNotEmpty) {
      return completers.removeAt(0).future;
    }

    if (results.isNotEmpty) {
      return Future.value(results.removeAt(0));
    }

    return Future.value(StorySoundtrack.noMusic());
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) {
    throw UnimplementedError();
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) {
    throw UnimplementedError();
  }
}

final class FakePlaybackAudioController implements PlaybackAudioController {
  final List<String> prepareStoryIds = <String>[];
  final StreamController<PlaybackAudioState> _stateController =
      StreamController<PlaybackAudioState>.broadcast();

  Object? prepareFailure;
  PlaybackAudioState stateAfterPrepare = PlaybackAudioState.ready();
  PlaybackAudioState _state = PlaybackAudioState.idle();

  @override
  PlaybackAudioState get state => _state;

  @override
  Stream<PlaybackAudioState> get stateStream => _stateController.stream;

  @override
  Future<void> prepare({required String storyId}) async {
    prepareStoryIds.add(storyId);
    final failure = prepareFailure;
    if (failure != null) {
      throw failure;
    }

    _state = stateAfterPrepare;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> restart() async {}

  @override
  Future<void> stop() async {}
}

final class PrivateMusicException implements Exception {
  const PrivateMusicException();
}

final class PrivateAudioException implements Exception {
  const PrivateAudioException();
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

  @override
  String toString() {
    return 'FakePlaybackScheduler(taskCount: ${tasks.length}, '
        'activeTaskCount: $activeTaskCount)';
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

  @override
  String toString() {
    return 'FakePlaybackScheduledTask(delay: $delay, '
        'isCanceled: $isCanceled, hasFired: $hasFired)';
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
  final List<String> operations = <String>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    receivedStoryIds.add(storyId);
    operations.add('getMemories');

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
    operations.add('getMemory');

    return readModel(memoryA);
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
