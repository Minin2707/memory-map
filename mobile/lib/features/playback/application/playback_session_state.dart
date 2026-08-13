import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/playback/application/playback_camera_failure.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';

final class PlaybackSessionState {
  factory PlaybackSessionState.loading() {
    return const PlaybackSessionState._(
      isLoading: true,
      playback: null,
      loadFailure: null,
      cameraFailure: null,
    );
  }

  factory PlaybackSessionState.session(
    StoryPlaybackState playback, {
    PlaybackCameraFailure? cameraFailure,
  }) {
    return PlaybackSessionState._(
      isLoading: false,
      playback: playback,
      loadFailure: null,
      cameraFailure: cameraFailure,
    );
  }

  factory PlaybackSessionState.failure(MemoryFailure failure) {
    return PlaybackSessionState._(
      isLoading: false,
      playback: null,
      loadFailure: failure,
      cameraFailure: null,
    );
  }

  const PlaybackSessionState._({
    required this.isLoading,
    required this.playback,
    required this.loadFailure,
    required this.cameraFailure,
  });

  final bool isLoading;
  final StoryPlaybackState? playback;
  final MemoryFailure? loadFailure;
  final PlaybackCameraFailure? cameraFailure;

  bool get hasSession => playback != null;

  bool get hasLoadFailure => loadFailure != null;

  bool get hasCameraFailure => cameraFailure != null;

  StoryPlaybackState get requirePlayback {
    final current = playback;
    if (current == null) {
      throw StateError('Playback session is not available');
    }

    return current;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackSessionState &&
            isLoading == other.isLoading &&
            playback == other.playback &&
            loadFailure == other.loadFailure &&
            cameraFailure == other.cameraFailure;
  }

  @override
  int get hashCode => Object.hash(
        isLoading,
        playback,
        loadFailure,
        cameraFailure,
      );

  @override
  String toString() {
    return 'PlaybackSessionState(isLoading: $isLoading, '
        'hasSession: $hasSession, hasLoadFailure: $hasLoadFailure, '
        'hasCameraFailure: $hasCameraFailure)';
  }
}
