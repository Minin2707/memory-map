import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/application/authorized_session_exception.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';

typedef JustAudioPlayerPortFactory = JustAudioPlayerPort Function();
typedef JustAudioAudioPlayerFactory = AudioPlayer Function({
  required bool useProxyForRequestHeaders,
});

enum JustAudioPlayerProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
}

final class JustAudioPlayerState {
  const JustAudioPlayerState({
    required this.processingState,
    required this.playing,
  });

  final JustAudioPlayerProcessingState processingState;
  final bool playing;
}

abstract interface class JustAudioPlayerPort {
  Stream<JustAudioPlayerState> get playerStateStream;

  Future<void> setAudioSource(
    Uri uri, {
    required Map<String, String> headers,
  });

  Future<void> play();

  Future<void> setVolume(double volume);

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> dispose();
}

final class DefaultJustAudioPlayerPort implements JustAudioPlayerPort {
  DefaultJustAudioPlayerPort({
    AudioPlayer? player,
    JustAudioAudioPlayerFactory audioPlayerFactory =
        _defaultAudioPlayerFactory,
  }) : _player = player ??
            audioPlayerFactory(useProxyForRequestHeaders: false);

  final AudioPlayer _player;

  @override
  Stream<JustAudioPlayerState> get playerStateStream {
    return _player.playerStateStream.map(_toPlayerState);
  }

  @override
  Future<void> setAudioSource(
    Uri uri, {
    required Map<String, String> headers,
  }) {
    return _player.setAudioSource(
      AudioSource.uri(
        uri,
        headers: headers,
      ),
    );
  }

  @override
  Future<void> play() {
    return _player.play();
  }

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume(volume);
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> seek(Duration position) {
    return _player.seek(position);
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}

AudioPlayer _defaultAudioPlayerFactory({
  required bool useProxyForRequestHeaders,
}) {
  return AudioPlayer(
    useProxyForRequestHeaders: useProxyForRequestHeaders,
  );
}

final class JustAudioPlaybackAudioController
    implements PlaybackAudioController {
  JustAudioPlaybackAudioController({
    required AppConfig appConfig,
    required AuthorizedSessionManager authorizedSessionManager,
    required JustAudioPlayerPort player,
  })  : _appConfig = appConfig,
        _authorizedSessionManager = authorizedSessionManager,
        _player = player {
    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerState,
      onError: (_) => _fail(const UnknownPlaybackAudioFailure()),
    );
  }

  final AppConfig _appConfig;
  final AuthorizedSessionManager _authorizedSessionManager;
  final JustAudioPlayerPort _player;
  final StreamController<PlaybackAudioState> _stateController =
      StreamController<PlaybackAudioState>.broadcast();

  late final StreamSubscription<JustAudioPlayerState> _playerStateSubscription;
  PlaybackAudioState _state = PlaybackAudioState.idle();
  bool _hasPreparedSource = false;
  bool _isDisposed = false;

  @override
  PlaybackAudioState get state => _state;

  @override
  Stream<PlaybackAudioState> get stateStream => _stateController.stream;

  @override
  Future<void> prepare({
    required String storyId,
  }) async {
    if (_isDisposed) {
      return;
    }

    final normalizedStoryId = storyId.trim();
    if (normalizedStoryId.isEmpty) {
      _fail(const PlaybackAudioValidationFailure());
      return;
    }

    _emit(PlaybackAudioState.preparing());

    try {
      final currentSession =
          await _authorizedSessionManager.getCurrentSession();
      if (currentSession == null) {
        _fail(const PlaybackAudioAuthenticationFailure());
        return;
      }

      final refreshedSession = await _authorizedSessionManager
          .refreshCurrentSession(currentSession);
      final audioUri = _soundtrackAudioUri(
        _appConfig.apiBaseUrl,
        normalizedStoryId,
      );

      await _player.setAudioSource(
        audioUri,
        headers: {
          'Authorization':
              'Bearer ${refreshedSession.tokens.accessToken}',
        },
      );

      if (_isDisposed) {
        return;
      }

      _hasPreparedSource = true;
      _emit(PlaybackAudioState.ready());
    } on AuthorizedSessionException {
      _fail(const PlaybackAudioAuthenticationFailure());
    } on Object {
      _fail(const PlaybackAudioUnavailableFailure());
    }
  }

  @override
  Future<void> play() async {
    if (!_canUsePreparedSource) {
      return;
    }

    unawaited(_playAndCaptureFailure());
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!_canUsePreparedSource) {
      return;
    }

    try {
      await _player.setVolume(volume.clamp(0.0, 1.0).toDouble());
    } on Object {
      _fail(const PlaybackAudioUnavailableFailure());
    }
  }

  @override
  Future<void> pause() async {
    if (!_canUsePreparedSource) {
      return;
    }

    try {
      await _player.pause();
      _emit(PlaybackAudioState.paused());
    } on Object {
      _fail(const PlaybackAudioUnavailableFailure());
    }
  }

  @override
  Future<void> stop() async {
    if (!_canUsePreparedSource) {
      return;
    }

    try {
      await _player.pause();
      await _player.seek(Duration.zero);
      _emit(PlaybackAudioState.ready());
    } on Object {
      _fail(const PlaybackAudioUnavailableFailure());
    }
  }

  @override
  Future<void> restart() async {
    if (!_canUsePreparedSource) {
      return;
    }

    try {
      await _player.seek(Duration.zero);
      unawaited(_playAndCaptureFailure());
    } on Object {
      _fail(const PlaybackAudioUnavailableFailure());
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    await _playerStateSubscription.cancel();
    await _player.dispose();
    await _stateController.close();
  }

  Future<void> _playAndCaptureFailure() async {
    try {
      await _player.play();
    } on Object {
      _fail(const PlaybackAudioUnavailableFailure());
    }
  }

  void _handlePlayerState(JustAudioPlayerState playerState) {
    if (_isDisposed) {
      return;
    }

    if (playerState.processingState ==
        JustAudioPlayerProcessingState.completed) {
      _emit(PlaybackAudioState.completed());
      return;
    }

    if (playerState.playing) {
      _emit(PlaybackAudioState.playing());
    }
  }

  void _fail(PlaybackAudioFailure failure) {
    _hasPreparedSource = false;
    _emit(PlaybackAudioState.failed(failure));
  }

  void _emit(PlaybackAudioState nextState) {
    if (_isDisposed || _state == nextState) {
      return;
    }

    _state = nextState;
    _stateController.add(nextState);
  }

  bool get _canUsePreparedSource => !_isDisposed && _hasPreparedSource;
}

JustAudioPlayerState _toPlayerState(PlayerState state) {
  return JustAudioPlayerState(
    processingState: _toProcessingState(state.processingState),
    playing: state.playing,
  );
}

JustAudioPlayerProcessingState _toProcessingState(
  ProcessingState processingState,
) {
  return switch (processingState) {
    ProcessingState.idle => JustAudioPlayerProcessingState.idle,
    ProcessingState.loading => JustAudioPlayerProcessingState.loading,
    ProcessingState.buffering => JustAudioPlayerProcessingState.buffering,
    ProcessingState.ready => JustAudioPlayerProcessingState.ready,
    ProcessingState.completed => JustAudioPlayerProcessingState.completed,
  };
}

Uri _soundtrackAudioUri(String apiBaseUrl, String storyId) {
  final baseUri = Uri.parse(apiBaseUrl);
  final basePathSegments =
      baseUri.pathSegments.where((segment) => segment.isNotEmpty);

  return baseUri.replace(
    pathSegments: [
      ...basePathSegments,
      'api',
      'v1',
      'stories',
      storyId,
      'soundtrack',
      'audio',
    ],
    queryParameters: null,
  );
}
