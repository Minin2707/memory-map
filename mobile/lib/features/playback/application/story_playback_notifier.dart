import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
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
  PlaybackScheduledTask? _presentationTask;
  int? _scheduledPresentationRevision;
  bool _hasCapturedInitialResource = false;

  @override
  PlaybackSessionState build() {
    _scheduler = ref.read(playbackSchedulerProvider);
    ref.onDispose(_cancelPresentationTask);

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
  }

  void retryCamera() {
    final current = state;
    if (!current.hasSession || !current.hasCameraFailure) {
      return;
    }

    _setPlayback(current.requirePlayback.retryCamera());
  }

  void presentationElapsed(int revision) {
    _transition((playback) => playback.presentationElapsed(revision));
  }

  void pause() {
    _transition((playback) => playback.pause());
  }

  void resume() {
    _transition((playback) => playback.resume());
  }

  void next() {
    _transition(
      (playback) => playback.next(),
      allowCameraFailure: true,
    );
  }

  void previous() {
    _transition(
      (playback) => playback.previous(),
      allowCameraFailure: true,
    );
  }

  void replay() {
    _transition(
      (playback) => playback.replay(),
      allowCameraFailure: true,
    );
  }

  void stop() {
    _transition(
      (playback) => playback.stop(),
      allowCameraFailure: true,
    );
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

    _hasCapturedInitialResource = true;
    return PlaybackSessionState.session(
      StoryPlaybackState.start(memoriesState.memoryReadModels),
    );
  }

  void _transition(
    StoryPlaybackState Function(StoryPlaybackState playback) transition, {
    bool allowCameraFailure = false,
  }) {
    final current = state;
    if (!current.hasSession) {
      return;
    }

    if (current.hasCameraFailure && !allowCameraFailure) {
      return;
    }

    final previousPlayback = current.requirePlayback;
    final nextPlayback = transition(previousPlayback);
    if (current.hasCameraFailure && nextPlayback == previousPlayback) {
      return;
    }

    _setPlayback(nextPlayback);
  }

  void _setPlayback(StoryPlaybackState nextPlayback) {
    final previousPlayback = state.playback;
    state = PlaybackSessionState.session(nextPlayback);
    _reconcilePresentationTimer(previousPlayback, nextPlayback);
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

        presentationElapsed(revision);
      },
    );
    _presentationTask = scheduledTask;
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
