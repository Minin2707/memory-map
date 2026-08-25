import 'dart:async';

import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';

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
  })  : _storySoundtrackRepository = storySoundtrackRepository,
        _audioController = audioController {
    _audioStateSubscription = _audioController.stateStream.listen(
      _handleAudioState,
      onError: (_) => _handleAudioState(
        PlaybackAudioState.failed(const UnknownPlaybackAudioFailure()),
      ),
    );
  }

  final StorySoundtrackRepository _storySoundtrackRepository;
  final PlaybackAudioController _audioController;

  int _generation = 0;
  PlaybackAudioSessionStatus _status = PlaybackAudioSessionStatus.idle;
  bool _desiredPlaying = false;
  bool _isDisposed = false;
  Future<void> _commandChain = Future<void>.value();
  late final StreamSubscription<PlaybackAudioState> _audioStateSubscription;

  @override
  PlaybackAudioSessionStatus get status => _status;

  @override
  Future<void> startSession({required String storyId}) async {
    if (_isDisposed) {
      return;
    }

    final generation = ++_generation;
    final normalizedStoryId = storyId.trim();
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

    _status = _audioController.state.hasFailure
        ? PlaybackAudioSessionStatus.disabled
        : PlaybackAudioSessionStatus.prepared;
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
  Future<void> finish() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredPlaying = false;
    return _stopIfCurrent(_generation);
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
    if (_isDisposed) {
      return;
    }

    _desiredPlaying = false;
    final generation = _generation;
    await _stopIfCurrent(generation);
    if (_isCurrent(generation)) {
      invalidateSession();
    }
  }

  @override
  void invalidateSession() {
    _generation++;
    _desiredPlaying = false;
    _status = PlaybackAudioSessionStatus.idle;
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    invalidateSession();
    _isDisposed = true;
    await _audioStateSubscription.cancel();
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

    _status = PlaybackAudioSessionStatus.disabled;
    _desiredPlaying = false;
  }

  Future<void> _playIfCurrent(int generation) {
    return _runCommandIfCurrent(generation, () async {
      await _audioController.play();
      if (_audioController.state.hasFailure) {
        _disableIfCurrent(generation);
        return;
      }

      if (_isCurrent(generation)) {
        _status = _audioController.state.isCompleted
            ? PlaybackAudioSessionStatus.completed
            : PlaybackAudioSessionStatus.playing;
      }
    });
  }

  Future<void> _pauseIfCurrent(int generation) {
    return _runCommandIfCurrent(generation, () async {
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
    return _runCommandIfCurrent(generation, () async {
      await _audioController.stop();
      if (_audioController.state.hasFailure) {
        _disableIfCurrent(generation);
        return;
      }

      if (_isCurrent(generation)) {
        _status = PlaybackAudioSessionStatus.prepared;
      }
    });
  }

  Future<void> _restartIfCurrent(int generation) {
    return _runCommandIfCurrent(
      generation,
      () async {
        await _audioController.restart();
        if (_audioController.state.hasFailure) {
          _disableIfCurrent(generation);
          return;
        }

        if (_isCurrent(generation)) {
          _status = PlaybackAudioSessionStatus.playing;
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
}
