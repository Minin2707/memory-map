import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/playback/application/playback_scheduler.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';

void main() {
  group('PlaybackAudioOrchestrator soundtrack snapshot', () {
    test('shouldMarkNoMusicSessionSilentWithoutPreparingAudio', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(StorySoundtrack.noMusic());
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.startSession(storyId: 'story-1');

      expect(orchestrator.status, PlaybackAudioSessionStatus.silent);
      expect(repository.operations, <String>['get:story-1']);
      expect(controller.prepareStoryIds, isEmpty);
    });

    test('shouldTreatSelectedUnavailableAsSilentWithoutPreparingAudio', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(StorySoundtrack(selectedSoundtrack: trackA));
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.startSession(storyId: 'story-1');

      expect(orchestrator.status, PlaybackAudioSessionStatus.silent);
      expect(repository.operations, <String>['get:story-1']);
      expect(controller.prepareStoryIds, isEmpty);
    });

    test('shouldPrepareOnceForFreshEffectiveSoundtrack', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(
          StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
        );
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.startSession(storyId: 'story-1');

      expect(orchestrator.status, PlaybackAudioSessionStatus.prepared);
      expect(repository.operations, <String>['get:story-1']);
      expect(controller.prepareStoryIds, <String>['story-1']);
      expect(controller.operations, <String>['prepare:story-1']);
    });

    test('shouldUseStoryIdRatherThanMusicTrackIdForAudioPrepare', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(
          StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
        );
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.startSession(storyId: 'story-1');

      expect(controller.prepareStoryIds, <String>['story-1']);
      expect(controller.prepareStoryIds, isNot(contains(trackA.id)));
    });

    test('shouldDisableSessionSilentlyWhenSoundtrackFetchFails', () async {
      final repository = FakeStorySoundtrackRepository()
        ..failures.add(const PrivateMusicException());
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.startSession(storyId: 'story-1');

      expect(orchestrator.status, PlaybackAudioSessionStatus.disabled);
      expect(repository.operations, <String>['get:story-1']);
      expect(controller.prepareStoryIds, isEmpty);
    });

    test('shouldDisableSessionSilentlyWhenPrepareThrows', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(
          StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
        );
      final controller = FakePlaybackAudioController()
        ..prepareFailure = const PrivateAudioException();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.startSession(storyId: 'story-1');

      expect(orchestrator.status, PlaybackAudioSessionStatus.disabled);
      expect(controller.prepareStoryIds, <String>['story-1']);
    });

    test('shouldDisableSessionWhenPrepareReportsFailedState', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(
          StorySoundtrack(
            selectedSoundtrack: trackA,
            effectiveSoundtrack: trackA,
          ),
        );
      final controller = FakePlaybackAudioController()
        ..stateAfterPrepare = PlaybackAudioState.failed(
          const PlaybackAudioUnavailableFailure(),
        );
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.startSession(storyId: 'story-1');

      expect(orchestrator.status, PlaybackAudioSessionStatus.disabled);
      expect(controller.prepareStoryIds, <String>['story-1']);
    });
  });

  group('PlaybackAudioOrchestrator stale async protection', () {
    test('shouldIgnoreLateSoundtrackResultAfterSessionInvalidation', () async {
      final soundtrackCompleter = Completer<StorySoundtrack>();
      final repository = FakeStorySoundtrackRepository()
        ..completers.add(soundtrackCompleter);
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      final session = orchestrator.startSession(storyId: 'story-1');
      expect(orchestrator.status, PlaybackAudioSessionStatus.resolving);

      orchestrator.invalidateSession();
      soundtrackCompleter.complete(
        StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        ),
      );
      await session;

      expect(orchestrator.status, PlaybackAudioSessionStatus.idle);
      expect(controller.prepareStoryIds, isEmpty);
    });

    test('shouldIgnoreLateSessionAResultAfterSessionBStarts', () async {
      final sessionACompleter = Completer<StorySoundtrack>();
      final sessionBCompleter = Completer<StorySoundtrack>();
      final repository = FakeStorySoundtrackRepository()
        ..completers.add(sessionACompleter)
        ..completers.add(sessionBCompleter);
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      final sessionA = orchestrator.startSession(storyId: 'story-a');
      final sessionB = orchestrator.startSession(storyId: 'story-b');

      sessionACompleter.complete(
        StorySoundtrack(
          selectedSoundtrack: trackA,
          effectiveSoundtrack: trackA,
        ),
      );
      sessionBCompleter.complete(StorySoundtrack.noMusic());
      await Future.wait([sessionA, sessionB]);

      expect(repository.operations, <String>['get:story-a', 'get:story-b']);
      expect(orchestrator.status, PlaybackAudioSessionStatus.silent);
      expect(controller.prepareStoryIds, isEmpty);
    });
  });

  group('PlaybackAudioOrchestrator lifecycle commands', () {
    test('shouldPlayWhenPrepareCompletesWhileVisualPlaybackWantsPlaying',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');

      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
      ]);
      expect(orchestrator.status, PlaybackAudioSessionStatus.playing);
    });

    test('shouldNotPlayWhenPrepareCompletesAfterPause', () async {
      final prepareCompleter = Completer<void>();
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController()
        ..prepareCompleter = prepareCompleter;
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      final session = orchestrator.startSession(storyId: 'story-1');
      await pumpEventQueue();
      await orchestrator.pause();
      prepareCompleter.complete();
      await session;

      expect(controller.operations, <String>['prepare:story-1']);

      await orchestrator.resume();

      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
      ]);
    });

    test('shouldNotPlayWhenPrepareCompletesAfterFinish', () async {
      final prepareCompleter = Completer<void>();
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController()
        ..prepareCompleter = prepareCompleter;
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      final session = orchestrator.startSession(storyId: 'story-1');
      await pumpEventQueue();
      await orchestrator.finish();
      prepareCompleter.complete();
      await session;

      expect(controller.operations, <String>['prepare:story-1']);
      expect(orchestrator.status, PlaybackAudioSessionStatus.prepared);
    });

    test('shouldIgnorePrepareCompletionAfterCloseInvalidatesSession', () async {
      final prepareCompleter = Completer<void>();
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController()
        ..prepareCompleter = prepareCompleter;
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      final session = orchestrator.startSession(storyId: 'story-1');
      await pumpEventQueue();
      await orchestrator.close();
      prepareCompleter.complete();
      await session;

      expect(controller.operations, <String>['prepare:story-1']);
      expect(orchestrator.status, PlaybackAudioSessionStatus.idle);
    });

    test('shouldMapPauseResumeFinishReplayAndCameraFailureToAudioCommands',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await orchestrator.pause();
      await orchestrator.resume();
      await orchestrator.cameraFailed();
      await orchestrator.resume();
      final finish = orchestrator.finish();
      await pumpEventQueue();
      await envelopeScheduler.fireAll();
      await finish;
      await orchestrator.replay();

      expect(controller.operations.take(7).toList(), <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
        'pause',
        'play',
        'pause',
        'play',
      ]);
      expect(controller.operations.where((operation) => operation == 'stop'),
          hasLength(1));
      expect(controller.operations, containsAllInOrder(<String>[
        'stop',
        'setVolume:0.0',
        'play',
      ]));
      expect(repository.operations, <String>['get:story-1']);
    });

    test('shouldKeepLifecycleCommandsNoopForSilentAndDisabledSessions',
        () async {
      final silentRepository = FakeStorySoundtrackRepository()
        ..results.add(StorySoundtrack.noMusic());
      final silentController = FakePlaybackAudioController();
      final silent = createOrchestrator(silentRepository, silentController);

      await silent.startSession(storyId: 'story-1');
      await silent.playbackStarted();
      await silent.pause();
      await silent.resume();
      await silent.finish();
      await silent.replay();

      expect(silentController.operations, isEmpty);

      final failedRepository = FakeStorySoundtrackRepository()
        ..failures.add(const PrivateMusicException());
      final failedController = FakePlaybackAudioController();
      final failed = createOrchestrator(failedRepository, failedController);

      await failed.startSession(storyId: 'story-1');
      await failed.playbackStarted();
      await failed.pause();
      await failed.resume();
      await failed.finish();
      await failed.replay();

      expect(failedController.operations, isEmpty);
    });

    test('shouldKeepReplaySilentAfterAudioFailureWithoutReprepare', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController()
        ..playFailure = const PrivateAudioException();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await orchestrator.replay();

      expect(orchestrator.status, PlaybackAudioSessionStatus.disabled);
      expect(repository.operations, <String>['get:story-1']);
      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
      ]);
    });

    test('shouldMarkSessionCompletedWhenAudioCompletesFirst', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController()
        ..stateAfterPlay = PlaybackAudioState.completed();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');

      expect(controller.state, PlaybackAudioState.completed());
      expect(orchestrator.status, PlaybackAudioSessionStatus.completed);
    });

    test('shouldNotRestartNaturallyCompletedAudioOnVisualResume', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      controller.emitState(PlaybackAudioState.completed());
      await pumpEventQueue();
      await orchestrator.pause();
      await orchestrator.resume();

      expect(orchestrator.status, PlaybackAudioSessionStatus.completed);
      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
      ]);
    });

    test('shouldRestartNaturallyCompletedAudioOnReplayWithoutRefetching',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      controller.emitState(PlaybackAudioState.completed());
      await pumpEventQueue();
      await orchestrator.replay();

      expect(orchestrator.status, PlaybackAudioSessionStatus.playing);
      expect(repository.operations, <String>['get:story-1']);
      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
        'setVolume:0.0',
        'restart',
      ]);
    });

    test('shouldDisableSessionOnPlayerFailureAndAvoidSameSessionRetry',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      controller.emitState(
        PlaybackAudioState.failed(const PlaybackAudioUnavailableFailure()),
      );
      await pumpEventQueue();
      await orchestrator.pause();
      await orchestrator.resume();
      await orchestrator.replay();

      expect(orchestrator.status, PlaybackAudioSessionStatus.disabled);
      expect(repository.operations, <String>['get:story-1']);
      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
      ]);
    });

    test('shouldAllowNewSessionToRetryAfterPreviousAudioFailure', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack())
        ..results.add(effectiveSoundtrack());
      final failedController = FakePlaybackAudioController();
      final failed = createOrchestrator(repository, failedController);

      await failed.playbackStarted();
      await failed.startSession(storyId: 'story-1');
      failedController.emitState(
        PlaybackAudioState.failed(const PlaybackAudioUnavailableFailure()),
      );
      await pumpEventQueue();

      final freshController = FakePlaybackAudioController();
      final fresh = createOrchestrator(repository, freshController);
      await fresh.playbackStarted();
      await fresh.startSession(storyId: 'story-1');

      expect(failed.status, PlaybackAudioSessionStatus.disabled);
      expect(fresh.status, PlaybackAudioSessionStatus.playing);
      expect(repository.operations, <String>['get:story-1', 'get:story-1']);
      expect(freshController.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
      ]);
    });

    test('shouldSerializeRapidPauseResumePauseToFinalPausedAudioState',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await Future.wait([
        orchestrator.pause(),
        orchestrator.resume(),
        orchestrator.pause(),
      ]);

      expect(orchestrator.status, PlaybackAudioSessionStatus.prepared);
      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
        'pause',
        'play',
        'pause',
      ]);
    });

    test('shouldDisableWithoutThrowingWhenAudioCommandsFail', () async {
      final pauseRepository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final pauseController = FakePlaybackAudioController()
        ..pauseFailure = const PrivateAudioException();
      final pauseOrchestrator =
          createOrchestrator(pauseRepository, pauseController);

      await pauseOrchestrator.playbackStarted();
      await pauseOrchestrator.startSession(storyId: 'story-1');
      await pauseOrchestrator.pause();
      expect(pauseOrchestrator.status, PlaybackAudioSessionStatus.disabled);

      final stopRepository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final stopController = FakePlaybackAudioController()
        ..stopFailure = const PrivateAudioException();
      final stopEnvelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final stopOrchestrator = createOrchestrator(
        stopRepository,
        stopController,
        envelopeScheduler: stopEnvelopeScheduler,
      );

      await stopOrchestrator.playbackStarted();
      await stopOrchestrator.startSession(storyId: 'story-1');
      final finish = stopOrchestrator.finish();
      await pumpEventQueue();
      await stopEnvelopeScheduler.fireAll();
      await finish;
      expect(stopOrchestrator.status, PlaybackAudioSessionStatus.disabled);
    });
  });

  group('PlaybackAudioOrchestrator soundtrack envelope', () {
    test('shouldExposeApprovedEnvelopePolicy', () {
      expect(playbackSoundtrackTargetVolume, 0.72);
      expect(
        playbackSoundtrackFadeInDuration,
        const Duration(milliseconds: 2000),
      );
      expect(
        playbackSoundtrackFinishFadeOutDuration,
        const Duration(milliseconds: 2800),
      );
      expect(
        playbackSoundtrackCloseFadeOutDuration,
        const Duration(milliseconds: 800),
      );
      expect(
        playbackSoundtrackEnvelopeStepDuration,
        const Duration(milliseconds: 100),
      );
    });

    test('shouldStartAtZeroAndFadeInToTargetVolume', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');

      expect(controller.volumes, <double>[0]);
      expect(controller.operations, containsAllInOrder(<String>[
        'prepare:story-1',
        'setVolume:0.0',
        'play',
      ]));
      expect(envelopeScheduler.activeTaskCount, 1);
      expect(
        envelopeScheduler.latest.delay,
        playbackSoundtrackEnvelopeStepDuration,
      );

      await envelopeScheduler.fireLatest();
      expect(controller.volumes.last, greaterThan(0));
      expect(controller.volumes.last, lessThan(playbackSoundtrackTargetVolume));

      await envelopeScheduler.fireAll();

      expect(controller.volumes.last, playbackSoundtrackTargetVolume);
      expect(envelopeScheduler.activeTaskCount, 0);
      expect(orchestrator.status, PlaybackAudioSessionStatus.playing);
    });

    test('shouldFadeOutBeforeNormalFinishStopsAudio', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await envelopeScheduler.fireAll();

      final finish = orchestrator.finish();
      await pumpEventQueue();

      expect(envelopeScheduler.activeTaskCount, 1);
      expect(
        controller.operations.where((operation) => operation == 'stop'),
        isEmpty,
      );

      await envelopeScheduler.fireAll();
      await finish;

      expect(controller.volumes.last, 0);
      expect(controller.operations.last, 'stop');
      expect(orchestrator.status, PlaybackAudioSessionStatus.prepared);
    });

    test('shouldUseShortFadeOutBeforeExplicitCloseInvalidatesSession',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await envelopeScheduler.fireAll();

      final close = orchestrator.close();
      await pumpEventQueue();

      expect(envelopeScheduler.activeTaskCount, 1);
      expect(
        envelopeScheduler.tasks.lastWhere((task) => task.isActive).delay,
        playbackSoundtrackEnvelopeStepDuration,
      );

      await envelopeScheduler.fireAll();
      await close;

      expect(controller.operations, contains('stop'));
      expect(controller.volumes.last, 0);
      expect(orchestrator.status, PlaybackAudioSessionStatus.idle);
    });

    test('shouldDisposeControllerOnlyAfterPendingExplicitCloseCompletes',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await envelopeScheduler.fireAll();

      final close = orchestrator.close();
      await pumpEventQueue();
      final dispose = orchestrator.dispose();
      await pumpEventQueue();

      expect(controller.disposeCalls, 0);
      expect(controller.operations.where((operation) => operation == 'stop'),
          isEmpty);

      await envelopeScheduler.fireAll();
      await close;
      await dispose;

      expect(controller.operations, containsAllInOrder(<String>[
        'stop',
        'dispose',
      ]));
      expect(controller.disposeCalls, 1);
    });

    test('shouldMakeDuplicateExplicitCloseShareOneStop', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await envelopeScheduler.fireAll();

      final firstClose = orchestrator.close();
      final secondClose = orchestrator.close();
      await pumpEventQueue();
      await envelopeScheduler.fireAll();
      await Future.wait(<Future<void>>[firstClose, secondClose]);

      expect(controller.operations.where((operation) => operation == 'stop'),
          hasLength(1));
      expect(orchestrator.status, PlaybackAudioSessionStatus.idle);
    });

    test('shouldCancelFadeInAndStopImmediatelyWhenDisposedWithoutClose',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');

      expect(envelopeScheduler.activeTaskCount, 1);

      await orchestrator.dispose();

      expect(envelopeScheduler.activeTaskCount, 0);
      expect(controller.operations, containsAllInOrder(<String>[
        'stop',
        'dispose',
      ]));
      expect(controller.disposeCalls, 1);
      final volumeCountAfterDispose = controller.volumes.length;
      await envelopeScheduler.fireAll();
      expect(controller.volumes, hasLength(volumeCountAfterDispose));
    });

    test('shouldWaitForPendingPrepareBeforeControllerDispose', () async {
      final prepareCompleter = Completer<void>();
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController()
        ..prepareCompleter = prepareCompleter;
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      final session = orchestrator.startSession(storyId: 'story-1');
      await pumpEventQueue();

      final dispose = orchestrator.dispose();
      await pumpEventQueue();

      expect(controller.disposeCalls, 0);

      prepareCompleter.complete();
      await session;
      await dispose;

      expect(controller.operations, <String>[
        'prepare:story-1',
        'dispose',
      ]);
      expect(controller.disposeCalls, 1);
      expect(orchestrator.status, PlaybackAudioSessionStatus.idle);
    });

    test('shouldCancelFadeInOnPauseAndResumeFromCurrentVolume', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await envelopeScheduler.fireLatest();
      final pausedVolume = controller.volumes.last;

      await orchestrator.pause();

      expect(envelopeScheduler.activeTaskCount, 0);
      expect(controller.operations.last, 'pause');

      await orchestrator.resume();

      expect(controller.operations.where((operation) => operation == 'play'),
          hasLength(2));
      expect(
        controller.operations.where(
          (operation) => operation == 'setVolume:0.0',
        ),
        hasLength(1),
      );
      expect(controller.volumes.last, pausedVolume);
      expect(envelopeScheduler.activeTaskCount, 1);

      await envelopeScheduler.fireAll();

      expect(controller.volumes.last, playbackSoundtrackTargetVolume);
    });

    test('shouldNotStartDuplicateFadeAfterCompletedFadePauseResume',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await envelopeScheduler.fireAll();

      await orchestrator.pause();
      await orchestrator.resume();

      expect(controller.volumes.last, playbackSoundtrackTargetVolume);
      expect(envelopeScheduler.activeTaskCount, 0);
    });

    test('shouldReplayAfterFadeOutFromSilentVolumeAndFadeInAgain', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await envelopeScheduler.fireAll();
      final finish = orchestrator.finish();
      await pumpEventQueue();
      await envelopeScheduler.fireAll();
      await finish;

      await orchestrator.replay();

      expect(controller.operations, containsAllInOrder(<String>[
        'stop',
        'setVolume:0.0',
        'play',
      ]));
      expect(controller.volumes.last, 0);

      await envelopeScheduler.fireAll();

      expect(controller.volumes.last, playbackSoundtrackTargetVolume);
    });

    test('shouldDisableSessionWithoutThrowingWhenVolumeChangeFails',
        () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController()
        ..setVolumeFailure = const PrivateAudioException();
      final orchestrator = createOrchestrator(repository, controller);

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');

      expect(orchestrator.status, PlaybackAudioSessionStatus.disabled);
      expect(controller.operations, <String>[
        'prepare:story-1',
        'setVolume:0.0',
      ]);
    });

    test('shouldCancelActiveFadeOnDispose', () async {
      final repository = FakeStorySoundtrackRepository()
        ..results.add(effectiveSoundtrack());
      final controller = FakePlaybackAudioController();
      final envelopeScheduler = FakePlaybackAudioEnvelopeScheduler();
      final orchestrator = createOrchestrator(
        repository,
        controller,
        envelopeScheduler: envelopeScheduler,
      );

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');

      expect(envelopeScheduler.activeTaskCount, 1);

      await orchestrator.dispose();

      expect(envelopeScheduler.activeTaskCount, 0);
      expect(controller.disposeCalls, 1);
      final volumeCountAfterDispose = controller.volumes.length;
      await envelopeScheduler.fireAll();
      expect(controller.volumes, hasLength(volumeCountAfterDispose));
    });
  });
}

PlaybackAudioOrchestrator createOrchestrator(
  FakeStorySoundtrackRepository repository,
  FakePlaybackAudioController controller, {
  FakePlaybackAudioEnvelopeScheduler? envelopeScheduler,
}) {
  return PlaybackAudioOrchestrator(
    storySoundtrackRepository: repository,
    audioController: controller,
    envelopeScheduler: envelopeScheduler ?? FakePlaybackAudioEnvelopeScheduler(),
  );
}

final MusicTrack trackA = MusicTrack(
  id: 'track-secret-id',
  title: 'Autumn Leaves',
  artist: 'LofCosmos',
  durationSeconds: 270,
);

StorySoundtrack effectiveSoundtrack() {
  return StorySoundtrack(
    selectedSoundtrack: trackA,
    effectiveSoundtrack: trackA,
  );
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
  final List<String> operations = <String>[];
  final List<String> prepareStoryIds = <String>[];
  final List<double> volumes = <double>[];
  final StreamController<PlaybackAudioState> _stateController =
      StreamController<PlaybackAudioState>.broadcast();

  Object? prepareFailure;
  Object? playFailure;
  Object? setVolumeFailure;
  Object? pauseFailure;
  Object? restartFailure;
  Object? stopFailure;
  int disposeCalls = 0;
  Completer<void>? prepareCompleter;
  PlaybackAudioState stateAfterPrepare = PlaybackAudioState.ready();
  PlaybackAudioState stateAfterPlay = PlaybackAudioState.playing();
  PlaybackAudioState stateAfterRestart = PlaybackAudioState.playing();
  PlaybackAudioState _state = PlaybackAudioState.idle();

  @override
  PlaybackAudioState get state => _state;

  @override
  Stream<PlaybackAudioState> get stateStream => _stateController.stream;

  @override
  Future<void> prepare({required String storyId}) async {
    operations.add('prepare:$storyId');
    prepareStoryIds.add(storyId);
    final failure = prepareFailure;
    if (failure != null) {
      throw failure;
    }

    await prepareCompleter?.future;
    _state = stateAfterPrepare;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    operations.add('dispose');
    await _stateController.close();
  }

  @override
  Future<void> pause() async {
    operations.add('pause');
    final failure = pauseFailure;
    if (failure != null) {
      throw failure;
    }

    _state = PlaybackAudioState.paused();
    _stateController.add(_state);
  }

  @override
  Future<void> play() async {
    operations.add('play');
    final failure = playFailure;
    if (failure != null) {
      throw failure;
    }

    _state = stateAfterPlay;
    _stateController.add(_state);
  }

  @override
  Future<void> setVolume(double volume) async {
    operations.add('setVolume:$volume');
    volumes.add(volume);
    final failure = setVolumeFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> restart() async {
    operations.add('restart');
    final failure = restartFailure;
    if (failure != null) {
      throw failure;
    }

    _state = stateAfterRestart;
    _stateController.add(_state);
  }

  @override
  Future<void> stop() async {
    operations.add('stop');
    final failure = stopFailure;
    if (failure != null) {
      throw failure;
    }

    _state = PlaybackAudioState.ready();
    _stateController.add(_state);
  }

  void emitState(PlaybackAudioState state) {
    _state = state;
    _stateController.add(state);
  }
}

final class FakePlaybackAudioEnvelopeScheduler implements PlaybackScheduler {
  final List<FakePlaybackAudioEnvelopeTask> tasks =
      <FakePlaybackAudioEnvelopeTask>[];

  int get activeTaskCount => tasks.where((task) => task.isActive).length;

  FakePlaybackAudioEnvelopeTask get latest => tasks.last;

  @override
  PlaybackScheduledTask schedule(
    Duration delay,
    void Function() callback,
  ) {
    final task = FakePlaybackAudioEnvelopeTask(
      delay: delay,
      callback: callback,
    );
    tasks.add(task);
    return task;
  }

  Future<void> fireLatest() async {
    latest.fire();
    await pumpEventQueue();
  }

  Future<void> fireAll() async {
    while (tasks.any((task) => task.isActive)) {
      tasks.lastWhere((task) => task.isActive).fire();
      await pumpEventQueue();
    }
  }
}

final class FakePlaybackAudioEnvelopeTask implements PlaybackScheduledTask {
  FakePlaybackAudioEnvelopeTask({
    required this.delay,
    required this.callback,
  });

  final Duration delay;
  final void Function() callback;
  bool isCanceled = false;
  bool hasFired = false;

  bool get isActive => !isCanceled && !hasFired;

  @override
  void cancel() {
    isCanceled = true;
  }

  void fire() {
    if (!isActive) {
      return;
    }

    hasFired = true;
    callback();
  }
}

final class PrivateMusicException implements Exception {
  const PrivateMusicException();
}

final class PrivateAudioException implements Exception {
  const PrivateAudioException();
}
