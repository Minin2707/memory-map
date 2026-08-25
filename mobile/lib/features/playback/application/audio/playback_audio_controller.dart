import 'package:memory_map/features/playback/application/audio/playback_audio_state.dart';

abstract interface class PlaybackAudioController {
  PlaybackAudioState get state;

  Stream<PlaybackAudioState> get stateStream;

  Future<void> prepare({
    required String storyId,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> restart();

  Future<void> dispose();
}
