import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_provider.dart';
import 'package:memory_map/features/playback/application/playback_camera_failure.dart';
import 'package:memory_map/features/playback/application/playback_scheduler.dart';
import 'package:memory_map/features/playback/application/playback_scheduler_provider.dart';
import 'package:memory_map/features/playback/application/playback_session_state.dart';
import 'package:memory_map/features/playback/domain/playback_phase.dart';
import 'package:memory_map/features/playback/domain/playback_status.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';

final class StoryPlaybackNotifier extends Notifier<PlaybackSessionState> {
  StoryPlaybackNotifier(this._storyId);

  final String _storyId;
  PlaybackScheduler? _scheduler;
  PlaybackAudioSessionOrchestrator? _audioOrchestrator;
  PlaybackScheduledTask? _presentationTask;
  int? _scheduledPresentationRevision;
  bool _hasCapturedInitialResource = false;

  @override
  PlaybackSessionState build() {
    _scheduler = ref.read(playbackSchedulerProvider);
    final audioOrchestrator = ref.watch(
      playbackAudioOrchestratorProvider(_storyId),
    );
    _audioOrchestrator = audioOrchestrator;
    ref.onDispose(() {
      _cancelPresentationTask();
    });

    final memoriesValue = ref.watch(storyMemoriesProvider(_storyId));
    return _stateFromInitialResource(memoriesValue);
  }

  Future<void> retry() async {
    if (_hasCapturedInitialResource) {
      return;
    }

    await ref.read(storyMemoriesProvider(_storyId).notifier).retryLoad();
  }

  void cameraArrived(int revision) {
    final current = state;
    if (!current.hasSession || current.hasCameraFailure) {
      return;
    }

    _setPlayback(current.requirePlayback.cameraArrived(revision));
  }

  void cameraFailed(int revision) {
    final current = state;
    if (!current.hasSession || current.hasCameraFailure) {
      return;
    }

    final playback = current.requirePlayback;
    if (playback.status != PlaybackStatus.playing ||
        playback.phase != PlaybackPhase.moving ||
        playback.cameraCommand?.revision != revision) {
      return;
    }

    _cancelPresentationTask();
    state = PlaybackSessionState.session(
      playback,
      cameraFailure: PlaybackCameraFailure(revision: revision),
    );
    unawaited(_audioOrchestrator!.cameraFailed());
  }

  void retryCamera() {
    final current = state;
    if (!current.hasSession || !current.hasCameraFailure) {
      return;
    }

    if (_setPlayback(current.requirePlayback.retryCamera())) {
      unawaited(_audioOrchestrator!.resume());
    }
  }

  void presentationElapsed(int revision) {
    final wasFinished = state.playback?.isFinished == true;
    if (_transition((playback) => playback.presentationElapsed(revision)) &&
        !wasFinished &&
        state.playback?.isFinished == true) {
      unawaited(_audioOrchestrator!.finish());
    }
  }

  void presentationDismissed(int revision) {
    presentationElapsed(revision);
  }

  void pause() {
    if (_transition((playback) => playback.pause())) {
      unawaited(_audioOrchestrator!.pause());
    }
  }

  void resume() {
    if (_transition((playback) => playback.resume())) {
      unawaited(_audioOrchestrator!.resume());
    }
  }

  void next() {
    final wasFinished = state.playback?.isFinished == true;
    _transition(
      (playback) => playback.next(),
      allowCameraFailure: true,
    );
    if (!wasFinished && state.playback?.isFinished == true) {
      unawaited(_audioOrchestrator!.finish());
    }
  }

  void previous() {
    _transition(
      (playback) => playback.previous(),
      allowCameraFailure: true,
    );
  }

  void replay() {
    if (_transition(
      (playback) => playback.replay(),
      allowCameraFailure: true,
    )) {
      unawaited(_audioOrchestrator!.replay());
    }
  }

  void stop() {
    if (_transition(
      (playback) => playback.stop(),
      allowCameraFailure: true,
    )) {
      unawaited(_audioOrchestrator!.close());
    }
  }

  PlaybackSessionState _stateFromInitialResource(
    AsyncValue<StoryMemoriesState> memoriesValue,
  ) {
    if (_hasCapturedInitialResource) {
      return state;
    }

    if (memoriesValue.hasError) {
      return PlaybackSessionState.failure(const UnknownMemoryFailure());
    }

    final memoriesState = memoriesValue.asData?.value;
    if (memoriesState == null) {
      return PlaybackSessionState.loading();
    }

    if (memoriesState.hasLoadFailure) {
      return PlaybackSessionState.failure(memoriesState.loadFailure!);
    }

    final playback = StoryPlaybackState.start(memoriesState.memoryReadModels);
    _hasCapturedInitialResource = true;
    if (playback.hasSnapshot) {
      unawaited(_audioOrchestrator!.playbackStarted());
      unawaited(_audioOrchestrator!.startSession(storyId: _storyId));
    }

    return PlaybackSessionState.session(playback);
  }

  bool _transition(
    StoryPlaybackState Function(StoryPlaybackState playback) transition, {
    bool allowCameraFailure = false,
  }) {
    final current = state;
    if (!current.hasSession) {
      return false;
    }

    if (current.hasCameraFailure && !allowCameraFailure) {
      return false;
    }

    final previousPlayback = current.requirePlayback;
    final nextPlayback = transition(previousPlayback);
    if (current.hasCameraFailure && nextPlayback == previousPlayback) {
      return false;
    }

    return _setPlayback(nextPlayback);
  }

  bool _setPlayback(StoryPlaybackState nextPlayback) {
    final previousPlayback = state.playback;
    if (previousPlayback == nextPlayback) {
      return false;
    }

    state = PlaybackSessionState.session(nextPlayback);
    _reconcilePresentationTimer(previousPlayback, nextPlayback);
    return true;
  }

  void _reconcilePresentationTimer(
    StoryPlaybackState? previousPlayback,
    StoryPlaybackState nextPlayback,
  ) {
    if (!_needsPresentationTimer(nextPlayback)) {
      _cancelPresentationTask();
      return;
    }

    final revision = nextPlayback.presentationRevision;
    if (_presentationTask != null &&
        _scheduledPresentationRevision == revision &&
        _needsPresentationTimer(previousPlayback)) {
      return;
    }

    _cancelPresentationTask();
    _scheduledPresentationRevision = revision;
    late final PlaybackScheduledTask scheduledTask;
    scheduledTask = _scheduler!.schedule(
      nextPlayback.policy.presentationDuration,
      () {
        if (_presentationTask == scheduledTask &&
            _scheduledPresentationRevision == revision) {
          _presentationTask = null;
          _scheduledPresentationRevision = null;
        }

        if (!ref.mounted) {
          return;
        }

        _presentationDurationElapsed(revision);
      },
    );
    _presentationTask = scheduledTask;
  }

  void _presentationDurationElapsed(int revision) {
    final current = state.playback;
    if (current == null ||
        current.status != PlaybackStatus.playing ||
        current.phase != PlaybackPhase.presenting ||
        current.presentationRevision != revision) {
      return;
    }

    if (current.currentIndex == current.snapshot.length - 1) {
      presentationElapsed(revision);
      return;
    }

    _setPlayback(current.beginPresentationDismissal(revision));
  }

  bool _needsPresentationTimer(StoryPlaybackState? playback) {
    return playback != null &&
        playback.status == PlaybackStatus.playing &&
        playback.phase == PlaybackPhase.presenting;
  }

  void _cancelPresentationTask() {
    _presentationTask?.cancel();
    _presentationTask = null;
    _scheduledPresentationRevision = null;
  }
}
