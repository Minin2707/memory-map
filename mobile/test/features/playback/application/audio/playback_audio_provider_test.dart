import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/just_audio_playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_provider.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';
import 'package:memory_map/features/playback/application/playback_scheduler.dart';
import 'package:memory_map/features/playback/application/playback_scheduler_provider.dart';

import 'just_audio_playback_audio_controller_test.dart';

void main() {
  group('playbackAudioControllerProvider', () {
    test('shouldCreateIndependentControllerPerStoryProviderKey', () {
      final factory = FakeJustAudioPlayerPortFactory();
      final container = createProviderContainer(factory);
      addTearDown(container.dispose);

      final first = container.read(playbackAudioControllerProvider('story-1'));
      final second = container.read(playbackAudioControllerProvider('story-2'));

      expect(first, isNot(same(second)));
      expect(factory.players.length, 2);
    });

    test('shouldDisposeOwnedPlayerWhenProviderIsDisposed', () async {
      final factory = FakeJustAudioPlayerPortFactory();
      final container = createProviderContainer(factory);
      final subscription = container.listen(
        playbackAudioControllerProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final player = factory.players.single;

      subscription.close();
      await pumpEventQueue();
      container.dispose();

      expect(player.disposeCalls, 1);
    });

    test('shouldKeepControllerAliveThroughOrchestratorProvider', () async {
      final factory = FakeJustAudioPlayerPortFactory();
      final container = createProviderContainer(factory);
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );

      expect(
        container.read(playbackAudioOrchestratorProvider('story-1')),
        isA<PlaybackAudioOrchestrator>(),
      );
      expect(factory.players.length, 1);

      final player = factory.players.single;
      subscription.close();
      await pumpEventQueue();
      container.dispose();

      expect(player.disposeCalls, 1);
    });

    test('shouldRetainActiveAudioSessionAcrossTransientListenerLoss',
        () async {
      final controller = FakePlaybackAudioController();
      final scheduler = FakePlaybackScheduler();
      final container = createProviderContainer(
        FakeJustAudioPlayerPortFactory(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..results.add(effectiveSoundtrack()),
        audioController: controller,
        scheduler: scheduler,
      );
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final orchestrator =
          container.read(playbackAudioOrchestratorProvider('story-1'));

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');

      expect(controller.disposeCalls, 0);
      expect(controller.volumes, <double>[0]);
      expect(scheduler.activeTaskCount, 1);

      subscription.close();
      await pumpEventQueue();

      expect(controller.disposeCalls, 0);
      expect(scheduler.activeTaskCount, 1);

      await scheduler.fireLatest();

      expect(controller.disposeCalls, 0);
      expect(controller.volumes.last, greaterThan(0));

      container.dispose();
      await pumpEventQueue();

      expect(controller.disposeCalls, 1);
    });

    test('shouldRetainPausedActiveAudioSessionAcrossListenerLoss', () async {
      final controller = FakePlaybackAudioController();
      final container = createProviderContainer(
        FakeJustAudioPlayerPortFactory(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..results.add(effectiveSoundtrack()),
        audioController: controller,
        scheduler: FakePlaybackScheduler(),
      );
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final orchestrator =
          container.read(playbackAudioOrchestratorProvider('story-1'));

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await orchestrator.pause();
      subscription.close();
      await pumpEventQueue();

      expect(controller.operations, contains('pause'));
      expect(controller.disposeCalls, 0);

      container.dispose();
      await pumpEventQueue();

      expect(controller.disposeCalls, 1);
    });

    test('shouldReleaseActiveRetentionAfterExplicitCloseCompletes', () async {
      final controller = FakePlaybackAudioController();
      final scheduler = FakePlaybackScheduler();
      final container = createProviderContainer(
        FakeJustAudioPlayerPortFactory(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..results.add(effectiveSoundtrack()),
        audioController: controller,
        scheduler: scheduler,
      );
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final orchestrator =
          container.read(playbackAudioOrchestratorProvider('story-1'));

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await scheduler.fireLatest();
      subscription.close();

      final close = orchestrator.close();
      await pumpEventQueue();

      expect(controller.disposeCalls, 0);
      expect(controller.operations.where((operation) => operation == 'stop'),
          isEmpty);

      await scheduler.fireAll();
      await close;
      await pumpEventQueue();

      expect(controller.operations, containsAllInOrder(<String>[
        'stop',
        'dispose',
      ]));
      expect(controller.disposeCalls, 1);
    });

    test('shouldReleaseActiveRetentionAfterNaturalFinishCompletes', () async {
      final controller = FakePlaybackAudioController();
      final scheduler = FakePlaybackScheduler();
      final container = createProviderContainer(
        FakeJustAudioPlayerPortFactory(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..results.add(effectiveSoundtrack()),
        audioController: controller,
        scheduler: scheduler,
      );
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final orchestrator =
          container.read(playbackAudioOrchestratorProvider('story-1'));

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      await scheduler.fireLatest();
      subscription.close();

      final finish = orchestrator.finish();
      await pumpEventQueue();

      expect(controller.disposeCalls, 0);

      await scheduler.fireAll();
      await finish;
      await pumpEventQueue();

      expect(controller.operations, containsAllInOrder(<String>[
        'stop',
        'dispose',
      ]));
      expect(controller.disposeCalls, 1);
    });

    test('shouldKeepDuplicateCloseIdempotentWhileReleasingRetention', () async {
      final controller = FakePlaybackAudioController();
      final scheduler = FakePlaybackScheduler();
      final container = createProviderContainer(
        FakeJustAudioPlayerPortFactory(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..results.add(effectiveSoundtrack()),
        audioController: controller,
        scheduler: scheduler,
      );
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final orchestrator =
          container.read(playbackAudioOrchestratorProvider('story-1'));

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      subscription.close();

      final firstClose = orchestrator.close();
      final secondClose = orchestrator.close();
      await pumpEventQueue();
      await scheduler.fireAll();
      await Future.wait(<Future<void>>[firstClose, secondClose]);
      await pumpEventQueue();

      expect(controller.operations.where((operation) => operation == 'stop'),
          hasLength(1));
      expect(controller.disposeCalls, 1);
    });

    test('shouldCreateFreshRetentionWhenReplayingAfterNaturalFinish', () async {
      final controller = FakePlaybackAudioController();
      final scheduler = FakePlaybackScheduler();
      final container = createProviderContainer(
        FakeJustAudioPlayerPortFactory(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..results.add(effectiveSoundtrack()),
        audioController: controller,
        scheduler: scheduler,
      );
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final orchestrator =
          container.read(playbackAudioOrchestratorProvider('story-1'));

      await orchestrator.playbackStarted();
      await orchestrator.startSession(storyId: 'story-1');
      final finish = orchestrator.finish();
      await pumpEventQueue();
      await scheduler.fireAll();
      await finish;

      await orchestrator.replay();
      subscription.close();
      await pumpEventQueue();

      expect(controller.operations, containsAllInOrder(<String>[
        'stop',
        'setVolume:0.0',
        'play',
      ]));
      expect(controller.disposeCalls, 0);

      container.dispose();
      await pumpEventQueue();

      expect(controller.disposeCalls, 1);
    });

    test('shouldNotRetainNoMusicSessionAfterResolve', () async {
      final controller = FakePlaybackAudioController();
      final container = createProviderContainer(
        FakeJustAudioPlayerPortFactory(),
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..results.add(StorySoundtrack.noMusic()),
        audioController: controller,
        scheduler: FakePlaybackScheduler(),
      );
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final orchestrator =
          container.read(playbackAudioOrchestratorProvider('story-1'));

      await orchestrator.startSession(storyId: 'story-1');
      subscription.close();
      await pumpEventQueue();

      expect(controller.operations, <String>['dispose']);
      expect(controller.disposeCalls, 1);
    });
  });
}

ProviderContainer createProviderContainer(
  FakeJustAudioPlayerPortFactory factory, {
  FakeStorySoundtrackRepository? soundtrackRepository,
  PlaybackAudioController? audioController,
  PlaybackScheduler? scheduler,
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(apiBaseUrl: 'https://api.example.test'),
      ),
      authorizedSessionManagerProvider.overrideWithValue(
        FakeAuthorizedSessionManager(),
      ),
      storySoundtrackRepositoryProvider.overrideWithValue(
        soundtrackRepository ?? FakeStorySoundtrackRepository(),
      ),
      justAudioPlayerPortFactoryProvider.overrideWithValue(factory.call),
      if (audioController != null)
        playbackAudioControllerFactoryProvider.overrideWithValue(
          (_) => audioController,
        ),
      if (scheduler != null)
        playbackSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
}

final class FakeJustAudioPlayerPortFactory {
  final List<FakeJustAudioPlayerPort> players = <FakeJustAudioPlayerPort>[];

  JustAudioPlayerPort call() {
    final player = FakeJustAudioPlayerPort();
    players.add(player);
    return player;
  }
}

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  final List<StorySoundtrack> results = <StorySoundtrack>[];

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    if (results.isNotEmpty) {
      return results.removeAt(0);
    }

    return StorySoundtrack.noMusic();
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

final MusicTrack trackA = MusicTrack(
  id: 'track-a',
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

final class FakePlaybackAudioController implements PlaybackAudioController {
  final List<String> operations = <String>[];
  final List<double> volumes = <double>[];
  final StreamController<PlaybackAudioState> _stateController =
      StreamController<PlaybackAudioState>.broadcast();

  int disposeCalls = 0;
  PlaybackAudioState _state = PlaybackAudioState.idle();

  @override
  PlaybackAudioState get state => _state;

  @override
  Stream<PlaybackAudioState> get stateStream => _stateController.stream;

  @override
  Future<void> prepare({required String storyId}) async {
    operations.add('prepare:$storyId');
    _state = PlaybackAudioState.ready();
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
    _state = PlaybackAudioState.paused();
    _stateController.add(_state);
  }

  @override
  Future<void> play() async {
    operations.add('play');
    _state = PlaybackAudioState.playing();
    _stateController.add(_state);
  }

  @override
  Future<void> restart() async {
    operations.add('restart');
    _state = PlaybackAudioState.playing();
    _stateController.add(_state);
  }

  @override
  Future<void> setVolume(double volume) async {
    operations.add('setVolume:$volume');
    volumes.add(volume);
  }

  @override
  Future<void> stop() async {
    operations.add('stop');
    _state = PlaybackAudioState.ready();
    _stateController.add(_state);
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
    final task = FakePlaybackScheduledTask(callback);
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

final class FakePlaybackScheduledTask implements PlaybackScheduledTask {
  FakePlaybackScheduledTask(this.callback);

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
