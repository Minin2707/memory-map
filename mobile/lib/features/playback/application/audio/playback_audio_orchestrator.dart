import 'dart:async';

import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/playback/application/playback_scheduler.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';
import 'package:memory_map/features/playback/domain/playback_policy.dart';

const double playbackSoundtrackTargetVolume = 0.72;
const Duration playbackSoundtrackFadeInDuration =
    playbackCinematicOpeningDuration;
const Duration playbackSoundtrackFinishFadeOutDuration =
    Duration(milliseconds: 2800);
const Duration playbackSoundtrackCloseFadeOutDuration =
    Duration(milliseconds: 800);
const Duration playbackSoundtrackEnvelopeStepDuration =
    Duration(milliseconds: 100);

enum PlaybackAudioSessionStatus {
  idle,
  resolving,
  silent,
  preparing,
  prepared,
  playing,
  completed,
  disabled,
}

abstract interface class PlaybackAudioSessionOrchestrator {
  PlaybackAudioSessionStatus get status;

  Future<void> startSession({required String storyId});

  Future<void> playbackStarted();

  Future<void> pause();

  Future<void> resume();

  Future<void> finish();

  Future<void> replay();

  Future<void> cameraFailed();

  Future<void> close();

  void invalidateSession();
}

final class PlaybackAudioOrchestrator
    implements PlaybackAudioSessionOrchestrator {
  PlaybackAudioOrchestrator({
    required StorySoundtrackRepository storySoundtrackRepository,
    required PlaybackAudioController audioController,
    required PlaybackScheduler envelopeScheduler,
    void Function()? retainSessionLifetime,
    void Function()? releaseSessionLifetime,
  })  : _storySoundtrackRepository = storySoundtrackRepository,
        _audioController = audioController,
        _envelopeScheduler = envelopeScheduler,
        _retainSessionLifetimeCallback = retainSessionLifetime,
        _releaseSessionLifetimeCallback = releaseSessionLifetime {
    _audioStateSubscription = _audioController.stateStream.listen(
      _handleAudioState,
      onError: (_) => _handleAudioState(
        PlaybackAudioState.failed(const UnknownPlaybackAudioFailure()),
      ),
    );
  }

  final StorySoundtrackRepository _storySoundtrackRepository;
  final PlaybackAudioController _audioController;
  final PlaybackScheduler _envelopeScheduler;
  final void Function()? _retainSessionLifetimeCallback;
  final void Function()? _releaseSessionLifetimeCallback;

  int _generation = 0;
  int _envelopeGeneration = 0;
  PlaybackAudioSessionStatus _status = PlaybackAudioSessionStatus.idle;
  bool _desiredPlaying = false;
  bool _hasStartedCurrentPlayback = false;
  bool _hasCompletedInitialFadeIn = false;
  bool _isDisposed = false;
  bool _hasDisposedController = false;
  bool _isSessionLifetimeRetained = false;
  double _currentVolume = playbackSoundtrackTargetVolume;
  Future<void> _commandChain = Future<void>.value();
  Future<void>? _sessionStartup;
  Future<void>? _closeFuture;
  Future<void>? _disposeFuture;
  PlaybackScheduledTask? _envelopeTask;
  Completer<void>? _envelopeCompleter;
  late final StreamSubscription<PlaybackAudioState> _audioStateSubscription;

  @override
  PlaybackAudioSessionStatus get status => _status;

  @override
  Future<void> startSession({required String storyId}) {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _retainSessionLifetime();
    late final Future<void> startup;
    startup = _startSession(storyId).whenComplete(() {
      if (identical(_sessionStartup, startup)) {
        _sessionStartup = null;
      }
    });
    _sessionStartup = startup;
    return startup;
  }

  Future<void> _startSession(String storyId) async {
    final generation = ++_generation;
    final normalizedStoryId = storyId.trim();
    _cancelEnvelope();
    _hasStartedCurrentPlayback = false;
    _hasCompletedInitialFadeIn = false;
    _currentVolume = playbackSoundtrackTargetVolume;
    _status = PlaybackAudioSessionStatus.resolving;

    if (normalizedStoryId.isEmpty) {
      _disableIfCurrent(generation);
      return;
    }

    final soundtrack = await _resolveSoundtrack(
      normalizedStoryId,
      generation,
    );
    if (soundtrack == null || !_isCurrent(generation)) {
      return;
    }

    if (soundtrack.effectiveSoundtrack == null) {
      _status = PlaybackAudioSessionStatus.silent;
      _releaseSessionLifetime();
      return;
    }

    _status = PlaybackAudioSessionStatus.preparing;
    try {
      await _audioController.prepare(storyId: normalizedStoryId);
    } on Object {
      _disableIfCurrent(generation);
      return;
    }

    if (!_isCurrent(generation)) {
      return;
    }

    if (_audioController.state.hasFailure) {
      _disableIfCurrent(generation);
      return;
    }

    _status = PlaybackAudioSessionStatus.prepared;
    if (_desiredPlaying && _isCurrent(generation)) {
      await _playIfCurrent(generation);
    }
  }

  @override
  Future<void> playbackStarted() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredPlaying = true;
    return _playIfCurrent(_generation);
  }

  @override
  Future<void> pause() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredPlaying = false;
    return _pauseIfCurrent(_generation);
  }

  @override
  Future<void> resume() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredPlaying = true;
    return _playIfCurrent(_generation);
  }

  @override
  Future<void> finish() async {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredPlaying = false;
    await _stopIfCurrent(_generation);
    _releaseSessionLifetime();
  }

  @override
  Future<void> replay() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredPlaying = true;
    if (_status == PlaybackAudioSessionStatus.completed) {
      return _restartIfCurrent(_generation);
    }

    return _playIfCurrent(_generation);
  }

  @override
  Future<void> cameraFailed() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredPlaying = false;
    return _pauseIfCurrent(_generation);
  }

  @override
  Future<void> close() async {
    _closeFuture ??= _closeOnce();
    return _closeFuture!;
  }

  @override
  void invalidateSession() {
    _generation++;
    _cancelEnvelope();
    _desiredPlaying = false;
    _hasStartedCurrentPlayback = false;
    _hasCompletedInitialFadeIn = false;
    _currentVolume = playbackSoundtrackTargetVolume;
    _status = PlaybackAudioSessionStatus.idle;
    _releaseSessionLifetime();
  }

  Future<void> dispose() async {
    _disposeFuture ??= _disposeOnce();
    return _disposeFuture!;
  }

  Future<StorySoundtrack?> _resolveSoundtrack(
    String storyId,
    int generation,
  ) async {
    try {
      return await _storySoundtrackRepository.getStorySoundtrack(storyId);
    } on Object {
      _disableIfCurrent(generation);
      return null;
    }
  }

  void _disableIfCurrent(int generation) {
    if (_isCurrent(generation)) {
      _disableCurrentSession();
    }
  }

  void _disableCurrentSession() {
    if (_isDisposed) {
      return;
    }

    _cancelEnvelope();
    _status = PlaybackAudioSessionStatus.disabled;
    _desiredPlaying = false;
    _releaseSessionLifetime();
  }

  Future<void> _playIfCurrent(int generation) {
    return _runCommandIfCurrent(generation, () async {
      _retainSessionLifetime();
      final shouldStartFresh = !_hasStartedCurrentPlayback;
      if (shouldStartFresh) {
        await _setVolumeIfCurrent(generation, 0);
        if (!_canCommandAudio(generation)) {
          return;
        }
      }

      await _audioController.play();
      if (_audioController.state.hasFailure) {
        _disableIfCurrent(generation);
        return;
      }

      if (_isCurrent(generation)) {
        _hasStartedCurrentPlayback = true;
        _status = _audioController.state.isCompleted
            ? PlaybackAudioSessionStatus.completed
            : PlaybackAudioSessionStatus.playing;
        if (!_audioController.state.isCompleted) {
          _startFadeIfCurrent(
            generation,
            to: playbackSoundtrackTargetVolume,
            duration: playbackSoundtrackFadeInDuration,
            markInitialFadeComplete: true,
          );
        }
      }
    });
  }

  Future<void> _pauseIfCurrent(int generation) {
    return _runCommandIfCurrent(generation, () async {
      _cancelEnvelope();
      await _audioController.pause();
      if (_audioController.state.hasFailure) {
        _disableIfCurrent(generation);
        return;
      }

      if (_isCurrent(generation)) {
        _status = PlaybackAudioSessionStatus.prepared;
      }
    });
  }

  Future<void> _stopIfCurrent(int generation) {
    return _fadeOutAndStopIfCurrent(
      generation,
      duration: playbackSoundtrackFinishFadeOutDuration,
    );
  }

  Future<void> _closeIfCurrent(int generation) {
    return _fadeOutAndStopIfCurrent(
      generation,
      duration: playbackSoundtrackCloseFadeOutDuration,
    );
  }

  Future<void> _closeOnce() async {
    if (_isDisposed) {
      return;
    }

    try {
      _desiredPlaying = false;
      final generation = _generation;
      await _closeIfCurrent(generation);
      if (_isCurrent(generation)) {
        invalidateSession();
      }
    } finally {
      _releaseSessionLifetime();
    }
  }

  Future<void> _disposeOnce() async {
    if (_isDisposed) {
      return;
    }

    try {
      final closeFuture = _closeFuture;
      if (closeFuture != null) {
        await closeFuture;
      } else {
        await _commandChain;
        await _stopForDisposeIfNeeded(_generation);
        invalidateSession();
      }
      await _awaitSessionStartup();
    } finally {
      _cancelEnvelope();
      _releaseSessionLifetime();
      _isDisposed = true;
      await _audioStateSubscription.cancel();
      await _disposeControllerOnce();
    }
  }

  Future<void> _awaitSessionStartup() async {
    while (true) {
      final startup = _sessionStartup;
      if (startup == null) {
        return;
      }

      await startup;
    }
  }

  Future<void> _stopForDisposeIfNeeded(int generation) {
    return _runCommandIfCurrent(
      generation,
      () async {
        _cancelEnvelope();
        if (!_hasStartedCurrentPlayback &&
            _status == PlaybackAudioSessionStatus.prepared) {
          return;
        }

        await _audioController.stop();
        if (_audioController.state.hasFailure) {
          _disableIfCurrent(generation);
          return;
        }

        if (_isCurrent(generation)) {
          _hasStartedCurrentPlayback = false;
          _hasCompletedInitialFadeIn = false;
          _currentVolume = 0;
          _status = PlaybackAudioSessionStatus.prepared;
        }
      },
      allowCompleted: true,
    );
  }

  Future<void> _disposeControllerOnce() async {
    if (_hasDisposedController) {
      return;
    }

    _hasDisposedController = true;
    try {
      await _audioController.dispose();
    } on Object {
      _disableCurrentSession();
    }
  }

  Future<void> _fadeOutAndStopIfCurrent(
    int generation, {
    required Duration duration,
  }) {
    return _runCommandIfCurrent(generation, () async {
      _hasCompletedInitialFadeIn = false;
      await _fadeVolumeIfCurrent(
        generation,
        to: 0,
        duration: duration,
        waitForCompletion: true,
      );
      if (!_canCommandAudio(generation)) {
        return;
      }

      await _audioController.stop();
      if (_audioController.state.hasFailure) {
        _disableIfCurrent(generation);
        return;
      }

      if (_isCurrent(generation)) {
        _hasStartedCurrentPlayback = false;
        _hasCompletedInitialFadeIn = false;
        _currentVolume = 0;
        _status = PlaybackAudioSessionStatus.prepared;
      }
    });
  }

  Future<void> _restartIfCurrent(int generation) {
    return _runCommandIfCurrent(
      generation,
      () async {
        _retainSessionLifetime();
        await _setVolumeIfCurrent(generation, 0, allowCompleted: true);
        if (!_canCommandAudio(generation, allowCompleted: true)) {
          return;
        }

        await _audioController.restart();
        if (_audioController.state.hasFailure) {
          _disableIfCurrent(generation);
          return;
        }

        if (_isCurrent(generation)) {
          _hasStartedCurrentPlayback = true;
          _hasCompletedInitialFadeIn = false;
          _status = PlaybackAudioSessionStatus.playing;
          _startFadeIfCurrent(
            generation,
            to: playbackSoundtrackTargetVolume,
            duration: playbackSoundtrackFadeInDuration,
            markInitialFadeComplete: true,
          );
        }
      },
      allowCompleted: true,
    );
  }

  Future<void> _runCommandIfCurrent(
    int generation,
    Future<void> Function() command, {
    bool allowCompleted = false,
  }) {
    _commandChain = _commandChain.then((_) async {
      if (!_canCommandAudio(generation, allowCompleted: allowCompleted)) {
        return;
      }

      try {
        await command();
      } on Object {
        _disableIfCurrent(generation);
      }
    });
    return _commandChain;
  }

  void _handleAudioState(PlaybackAudioState state) {
    if (_isDisposed ||
        _status == PlaybackAudioSessionStatus.idle ||
        _status == PlaybackAudioSessionStatus.resolving ||
        _status == PlaybackAudioSessionStatus.silent ||
        _status == PlaybackAudioSessionStatus.disabled) {
      return;
    }

    if (state.hasFailure) {
      _disableCurrentSession();
      return;
    }

    if (state.isCompleted && _status == PlaybackAudioSessionStatus.playing) {
      _cancelEnvelope();
      _status = PlaybackAudioSessionStatus.completed;
      _desiredPlaying = false;
    }
  }

  bool _canCommandAudio(
    int generation, {
    bool allowCompleted = false,
  }) {
    return _isCurrent(generation) &&
        (_status == PlaybackAudioSessionStatus.prepared ||
            _status == PlaybackAudioSessionStatus.playing ||
            (allowCompleted &&
                _status == PlaybackAudioSessionStatus.completed));
  }

  bool _isCurrent(int generation) => !_isDisposed && generation == _generation;

  void _retainSessionLifetime() {
    if (_isSessionLifetimeRetained) {
      return;
    }

    _isSessionLifetimeRetained = true;
    _retainSessionLifetimeCallback?.call();
  }

  void _releaseSessionLifetime() {
    if (!_isSessionLifetimeRetained) {
      return;
    }

    _isSessionLifetimeRetained = false;
    _releaseSessionLifetimeCallback?.call();
  }

  Future<void> _setVolumeIfCurrent(
    int generation,
    double volume, {
    bool allowCompleted = false,
  }) async {
    if (!_canCommandAudio(generation, allowCompleted: allowCompleted)) {
      return;
    }

    try {
      final safeVolume = volume.clamp(0.0, 1.0).toDouble();
      await _audioController.setVolume(safeVolume);
      if (_audioController.state.hasFailure) {
        _disableIfCurrent(generation);
        return;
      }

      if (_isCurrent(generation)) {
        _currentVolume = safeVolume;
      }
    } on Object {
      _disableIfCurrent(generation);
    }
  }

  void _startFadeIfCurrent(
    int generation, {
    required double to,
    required Duration duration,
    required bool markInitialFadeComplete,
  }) {
    if (!_isCurrent(generation)) {
      return;
    }

    if (markInitialFadeComplete && _hasCompletedInitialFadeIn) {
      return;
    }

    unawaited(
      _fadeVolumeIfCurrent(
        generation,
        to: to,
        duration: duration,
        waitForCompletion: false,
        markInitialFadeComplete: markInitialFadeComplete,
      ),
    );
  }

  Future<void> _fadeVolumeIfCurrent(
    int generation, {
    required double to,
    required Duration duration,
    required bool waitForCompletion,
    bool markInitialFadeComplete = false,
  }) {
    _cancelEnvelope();
    if (!_isCurrent(generation)) {
      return Future<void>.value();
    }

    final envelopeGeneration = _envelopeGeneration;
    final startVolume = _currentVolume.clamp(0.0, 1.0).toDouble();
    final targetVolume = to.clamp(0.0, 1.0).toDouble();
    final stepCount = _stepCountFor(duration);
    var step = 0;
    final completer = Completer<void>();
    _envelopeCompleter = completer;

    void completeEnvelope() {
      if (_envelopeCompleter == completer) {
        _envelopeCompleter = null;
      }

      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    void scheduleNextStep() {
      if (!_isCurrent(generation) ||
          envelopeGeneration != _envelopeGeneration ||
          _isDisposed) {
        completeEnvelope();
        return;
      }

      if (step >= stepCount) {
        if (markInitialFadeComplete && _isCurrent(generation)) {
          _hasCompletedInitialFadeIn = true;
        }
        completeEnvelope();
        return;
      }

      _envelopeTask = _envelopeScheduler.schedule(
        playbackSoundtrackEnvelopeStepDuration,
        () {
          unawaited(() async {
            if (!_isCurrent(generation) ||
                envelopeGeneration != _envelopeGeneration ||
                _isDisposed) {
              completeEnvelope();
              return;
            }

            step += 1;
            final progress = step / stepCount;
            final nextVolume =
                startVolume + (targetVolume - startVolume) * progress;
            await _setVolumeIfCurrent(generation, nextVolume);
            if (!_canCommandAudio(generation) ||
                envelopeGeneration != _envelopeGeneration) {
              completeEnvelope();
              return;
            }

            scheduleNextStep();
          }());
        },
      );
    }

    if (duration.compareTo(Duration.zero) <= 0 || startVolume == targetVolume) {
      unawaited(() async {
        await _setVolumeIfCurrent(generation, targetVolume);
        if (markInitialFadeComplete && _isCurrent(generation)) {
          _hasCompletedInitialFadeIn = true;
        }
        completeEnvelope();
      }());
    } else {
      scheduleNextStep();
    }

    return waitForCompletion ? completer.future : Future<void>.value();
  }

  void _cancelEnvelope() {
    _envelopeGeneration++;
    _envelopeTask?.cancel();
    _envelopeTask = null;
    final completer = _envelopeCompleter;
    _envelopeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

int _stepCountFor(Duration duration) {
  if (duration.compareTo(Duration.zero) <= 0) {
    return 1;
  }

  final rawSteps = duration.inMilliseconds /
      playbackSoundtrackEnvelopeStepDuration.inMilliseconds;
  return rawSteps.ceil().clamp(1, 1000).toInt();
}
