import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/playback/application/playback_camera_failure.dart';
import 'package:memory_map/features/playback/application/playback_session_state.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';

void main() {
  group('PlaybackSessionState', () {
    test('shouldRepresentLoadingState', () {
      final state = PlaybackSessionState.loading();

      expect(state.isLoading, isTrue);
      expect(state.hasSession, isFalse);
      expect(state.hasLoadFailure, isFalse);
      expect(state.playback, isNull);
      expect(state.loadFailure, isNull);
      expect(state.toString(), contains('isLoading: true'));
    });

    test('shouldRepresentSessionState', () {
      final playback = StoryPlaybackState.idle();
      final state = PlaybackSessionState.session(playback);

      expect(state.isLoading, isFalse);
      expect(state.hasSession, isTrue);
      expect(state.hasLoadFailure, isFalse);
      expect(state.hasCameraFailure, isFalse);
      expect(state.playback, same(playback));
      expect(state.requirePlayback, same(playback));
    });

    test('shouldRepresentRecoverableCameraFailureWithActiveSession', () {
      final playback = StoryPlaybackState.idle();
      final failure = PlaybackCameraFailure(revision: 7);
      final state = PlaybackSessionState.session(
        playback,
        cameraFailure: failure,
      );

      expect(state.isLoading, isFalse);
      expect(state.hasSession, isTrue);
      expect(state.hasLoadFailure, isFalse);
      expect(state.hasCameraFailure, isTrue);
      expect(state.cameraFailure, failure);
      expect(state.requirePlayback, same(playback));
    });

    test('shouldRepresentSafeFailureState', () {
      final state = PlaybackSessionState.failure(
        const MemoryStoryUnavailable(),
      );

      expect(state.isLoading, isFalse);
      expect(state.hasSession, isFalse);
      expect(state.hasLoadFailure, isTrue);
      expect(state.loadFailure, const MemoryStoryUnavailable());
      expect(state.playback, isNull);
    });

    test('shouldRejectRequiredPlaybackWhenUnavailable', () {
      final state = PlaybackSessionState.loading();

      expect(() => state.requirePlayback, throwsA(isA<StateError>()));
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = PlaybackSessionState.failure(
        const MemoryStoryUnavailable(),
      );
      final second = PlaybackSessionState.failure(
        const MemoryStoryUnavailable(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);

      final text = first.toString();
      expect(text, contains('hasLoadFailure: true'));
      expect(text, contains('hasCameraFailure: false'));
      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('private-memory-id')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('token')));
    });
  });

  group('PlaybackCameraFailure', () {
    test('shouldRejectInvalidRevision', () {
      expect(
        () => PlaybackCameraFailure(revision: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = PlaybackCameraFailure(revision: 5);
      final second = PlaybackCameraFailure(revision: 5);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), 'PlaybackCameraFailure(hasRevision: true)');
      expect(first.toString(), isNot(contains('5')));
      expect(first.toString(), isNot(contains('MapLibre')));
    });
  });
}
