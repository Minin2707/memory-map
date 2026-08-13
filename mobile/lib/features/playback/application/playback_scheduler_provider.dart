import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/playback/application/playback_scheduler.dart';
import 'package:memory_map/features/playback/application/timer_playback_scheduler.dart';

final playbackSchedulerProvider = Provider<PlaybackScheduler>((ref) {
  return const TimerPlaybackScheduler();
});
