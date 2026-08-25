import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';
import 'package:memory_map/features/playback/application/audio/just_audio_playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';

void main() {
  group('DefaultJustAudioPlayerPort construction', () {
    test('shouldDisableProxyForRequestHeadersInProductionPlayer', () {
      bool? configuredUseProxyForRequestHeaders;

      expect(
        () => DefaultJustAudioPlayerPort(
          audioPlayerFactory: ({
            required bool useProxyForRequestHeaders,
          }) {
            configuredUseProxyForRequestHeaders = useProxyForRequestHeaders;
            throw const StopAudioPlayerConstruction();
          },
        ),
        throwsA(isA<StopAudioPlayerConstruction>()),
      );

      expect(configuredUseProxyForRequestHeaders, isFalse);
    });
  });

  group('JustAudioPlaybackAudioController prepare', () {
    test('shouldStartIdleAndPrepareStoryScopedAuthenticatedSource', () async {
      final sessions = FakeAuthorizedSessionManager();
      final player = FakeJustAudioPlayerPort();
      final controller = createController(sessions, player);
      addTearDown(controller.dispose);

      expect(controller.state, PlaybackAudioState.idle());

      await controller.prepare(storyId: 'story-1');

      expect(controller.state, PlaybackAudioState.ready());
      expect(sessions.operations, <String>['getCurrent', 'refresh']);
      expect(player.operations, <String>['setAudioSource']);
      expect(
        player.latestUri.toString(),
        'https://api.example.test/base/api/v1/stories/story-1/'
        'soundtrack/audio',
      );
      expect(
        player.latestHeaders,
        <String, String>{'Authorization': 'Bearer refreshed-token'},
      );
      expect(player.latestHeaders!.containsKey('Range'), isFalse);
    });

    test('shouldExposeValidationFailureForBlankStoryId', () async {
      final sessions = FakeAuthorizedSessionManager();
      final player = FakeJustAudioPlayerPort();
      final controller = createController(sessions, player);
      addTearDown(controller.dispose);

      await controller.prepare(storyId: '   ');

      expect(
        controller.state,
        PlaybackAudioState.failed(const PlaybackAudioValidationFailure()),
      );
      expect(sessions.operations, isEmpty);
      expect(player.operations, isEmpty);
    });

    test('shouldExposeAuthenticationFailureWhenSessionIsMissing', () async {
      final sessions = FakeAuthorizedSessionManager()..currentSession = null;
      final player = FakeJustAudioPlayerPort();
      final controller = createController(sessions, player);
      addTearDown(controller.dispose);

      await controller.prepare(storyId: 'story-1');

      expect(
        controller.state,
        PlaybackAudioState.failed(
          const PlaybackAudioAuthenticationFailure(),
        ),
      );
      expect(player.operations, isEmpty);
    });

    test('shouldExposeNonfatalFailureWhenSourceSetupFails', () async {
      final sessions = FakeAuthorizedSessionManager();
      final player = FakeJustAudioPlayerPort()
        ..setAudioSourceFailure = const PrivateAudioException();
      final controller = createController(sessions, player);
      addTearDown(controller.dispose);

      await controller.prepare(storyId: 'story-1');

      expect(
        controller.state,
        PlaybackAudioState.failed(const PlaybackAudioUnavailableFailure()),
      );
      expect(controller.state.toString(), isNot(contains('private-token')));
    });
  });

  group('JustAudioPlaybackAudioController controls', () {
    test('shouldStartPlaybackWithoutAwaitingTrackCompletion', () async {
      final player = FakeJustAudioPlayerPort()
        ..playCompleter = Completer<void>();
      final controller = await preparedController(player: player);
      addTearDown(controller.dispose);

      await controller.play();

      expect(player.operations, <String>['setAudioSource', 'play']);
      expect(controller.state, PlaybackAudioState.ready());

      player.emit(
        const JustAudioPlayerState(
          processingState: JustAudioPlayerProcessingState.ready,
          playing: true,
        ),
      );
      await pumpEventQueue();

      expect(controller.state, PlaybackAudioState.playing());
      await controller.pause();
      expect(player.operations, <String>[
        'setAudioSource',
        'play',
        'pause',
      ]);

      player.playCompleter!.complete();
    });

    test('shouldPausePreparedSourceAndPreservePosition', () async {
      final player = FakeJustAudioPlayerPort();
      final controller = await preparedController(player: player);
      addTearDown(controller.dispose);

      await controller.pause();

      expect(player.operations, <String>['setAudioSource', 'pause']);
      expect(controller.state, PlaybackAudioState.paused());
      expect(player.seekPositions, isEmpty);
    });

    test('shouldRestartWithoutReloadingSource', () async {
      final player = FakeJustAudioPlayerPort();
      final controller = await preparedController(player: player);
      addTearDown(controller.dispose);

      await controller.restart();

      expect(player.operations, <String>[
        'setAudioSource',
        'seek:0',
        'play',
      ]);
      expect(player.latestUri?.path, contains('/stories/story-1/'));
    });

    test('shouldStopWithoutUnloadingPreparedSource', () async {
      final player = FakeJustAudioPlayerPort();
      final controller = await preparedController(player: player);
      addTearDown(controller.dispose);

      await controller.stop();
      await controller.play();

      expect(player.operations, <String>[
        'setAudioSource',
        'pause',
        'seek:0',
        'play',
      ]);
      expect(controller.state, PlaybackAudioState.ready());
    });

    test('shouldClampVolumeAndForwardToPlayer', () async {
      final player = FakeJustAudioPlayerPort();
      final controller = await preparedController(player: player);
      addTearDown(controller.dispose);

      await controller.setVolume(-0.5);
      await controller.setVolume(0.72);
      await controller.setVolume(1.4);

      expect(player.volumes, <double>[0, 0.72, 1]);
      expect(player.operations, <String>[
        'setAudioSource',
        'setVolume:0.0',
        'setVolume:0.72',
        'setVolume:1.0',
      ]);
    });

    test('shouldObserveCompletion', () async {
      final player = FakeJustAudioPlayerPort();
      final controller = await preparedController(player: player);
      addTearDown(controller.dispose);

      player.emit(
        const JustAudioPlayerState(
          processingState: JustAudioPlayerProcessingState.completed,
          playing: false,
        ),
      );
      await pumpEventQueue();

      expect(controller.state, PlaybackAudioState.completed());
    });

    test('shouldTreatAsyncPlayFailureAsNonfatalState', () async {
      final player = FakeJustAudioPlayerPort()
        ..playFailure = const PrivateAudioException();
      final controller = await preparedController(player: player);
      addTearDown(controller.dispose);

      await controller.play();
      await pumpEventQueue();

      expect(
        controller.state,
        PlaybackAudioState.failed(const PlaybackAudioUnavailableFailure()),
      );
      expect(controller.state.toString(), isNot(contains('private-token')));
    });
  });

  group('JustAudioPlaybackAudioController dispose', () {
    test('shouldReleasePlayerAndIgnoreRepeatedDispose', () async {
      final player = FakeJustAudioPlayerPort();
      final controller = await preparedController(player: player);

      await controller.dispose();
      await controller.dispose();

      expect(player.disposeCalls, 1);
      expect(player.operations, <String>[
        'setAudioSource',
        'dispose',
      ]);
    });
  });
}

JustAudioPlaybackAudioController createController(
  FakeAuthorizedSessionManager sessions,
  FakeJustAudioPlayerPort player,
) {
  return JustAudioPlaybackAudioController(
    appConfig: const AppConfig(apiBaseUrl: 'https://api.example.test/base'),
    authorizedSessionManager: sessions,
    player: player,
  );
}

Future<JustAudioPlaybackAudioController> preparedController({
  FakeJustAudioPlayerPort? player,
}) async {
  final controller = createController(
    FakeAuthorizedSessionManager(),
    player ?? FakeJustAudioPlayerPort(),
  );
  await controller.prepare(storyId: 'story-1');
  return controller;
}

AuthSession session(String accessToken) {
  return AuthSession(
    user: AuthUser(id: 'user-1', displayName: 'User One'),
    tokens: AuthTokens(
      accessToken: accessToken,
      refreshToken: 'refresh-token',
    ),
  );
}

final class FakeAuthorizedSessionManager
    implements AuthorizedSessionManager {
  final List<String> operations = <String>[];
  AuthSession? currentSession = session('current-token');
  AuthSession refreshedSession = session('refreshed-token');
  Object? refreshFailure;

  @override
  Future<AuthSession?> getCurrentSession() async {
    operations.add('getCurrent');
    return currentSession;
  }

  @override
  Future<AuthSession> refreshCurrentSession(AuthSession currentSession) async {
    operations.add('refresh');
    final configuredFailure = refreshFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return refreshedSession;
  }

  @override
  Future<void> invalidateCurrentSession(AuthSession currentSession) async {
    operations.add('invalidate');
  }
}

final class FakeJustAudioPlayerPort implements JustAudioPlayerPort {
  final StreamController<JustAudioPlayerState> _stateController =
      StreamController<JustAudioPlayerState>.broadcast();
  final List<String> operations = <String>[];
  final List<Duration> seekPositions = <Duration>[];
  final List<double> volumes = <double>[];
  Uri? latestUri;
  Map<String, String>? latestHeaders;
  Object? setAudioSourceFailure;
  Object? playFailure;
  Completer<void>? playCompleter;
  int disposeCalls = 0;

  @override
  Stream<JustAudioPlayerState> get playerStateStream =>
      _stateController.stream;

  @override
  Future<void> setAudioSource(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    operations.add('setAudioSource');
    latestUri = uri;
    latestHeaders = Map<String, String>.unmodifiable(headers);

    final configuredFailure = setAudioSourceFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }

  @override
  Future<void> play() async {
    operations.add('play');
    final configuredFailure = playFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    final completer = playCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    operations.add('setVolume:$volume');
    volumes.add(volume);
  }

  @override
  Future<void> pause() async {
    operations.add('pause');
  }

  @override
  Future<void> seek(Duration position) async {
    operations.add('seek:${position.inMilliseconds}');
    seekPositions.add(position);
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    operations.add('dispose');
    await _stateController.close();
  }

  void emit(JustAudioPlayerState state) {
    _stateController.add(state);
  }
}

final class PrivateAudioException implements Exception {
  const PrivateAudioException();

  @override
  String toString() {
    return 'PrivateAudioException(Bearer private-token, storageKey=secret)';
  }
}

final class StopAudioPlayerConstruction implements Exception {
  const StopAudioPlayerConstruction();
}
