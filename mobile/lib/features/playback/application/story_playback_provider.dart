import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/playback/application/playback_session_state.dart';
import 'package:memory_map/features/playback/application/story_playback_notifier.dart';

final storyPlaybackProvider = NotifierProvider.autoDispose
    .family<StoryPlaybackNotifier, PlaybackSessionState, String>(
  StoryPlaybackNotifier.new,
);
