import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';

void main() {
  group('PlaybackAudioState', () {
    test('shouldRepresentInitialAndOperationalStates', () {
      expect(PlaybackAudioState.idle().isIdle, isTrue);
      expect(PlaybackAudioState.preparing().isPreparing, isTrue);
      expect(PlaybackAudioState.ready().isReady, isTrue);
      expect(PlaybackAudioState.playing().isPlaying, isTrue);
      expect(PlaybackAudioState.paused().isPaused, isTrue);
      expect(PlaybackAudioState.completed().isCompleted, isTrue);
    });

    test('shouldRepresentSafeFailureState', () {
      final state = PlaybackAudioState.failed(
        const PlaybackAudioAuthenticationFailure(),
      );

      expect(state.status, PlaybackAudioStatus.failed);
      expect(state.hasFailure, isTrue);
      expect(state.failure, const PlaybackAudioAuthenticationFailure());
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = PlaybackAudioState.failed(
        const PlaybackAudioUnavailableFailure(),
      );
      final second = PlaybackAudioState.failed(
        const PlaybackAudioUnavailableFailure(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);

      final text = first.toString();
      expect(text, contains('hasFailure: true'));
      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('Bearer')));
      expect(text, isNot(contains('token')));
      expect(text, isNot(contains('storageKey')));
      expect(text, isNot(contains('MinIO')));
    });
  });

  group('PlaybackAudioFailure', () {
    test('shouldUseTypeEqualityAndSafeToString', () {
      expect(
        const PlaybackAudioValidationFailure(),
        const PlaybackAudioValidationFailure(),
      );
      expect(
        const PlaybackAudioAuthenticationFailure(),
        isNot(const PlaybackAudioUnavailableFailure()),
      );
      expect(
        const UnknownPlaybackAudioFailure().toString(),
        'UnknownPlaybackAudioFailure',
      );
    });
  });
}
