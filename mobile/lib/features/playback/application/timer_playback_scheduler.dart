import 'dart:async';

import 'package:memory_map/features/playback/application/playback_scheduler.dart';

final class TimerPlaybackScheduler implements PlaybackScheduler {
  const TimerPlaybackScheduler();

  @override
  PlaybackScheduledTask schedule(
    Duration delay,
    void Function() callback,
  ) {
    return _TimerPlaybackScheduledTask(Timer(delay, callback));
  }
}

final class _TimerPlaybackScheduledTask implements PlaybackScheduledTask {
  _TimerPlaybackScheduledTask(this._timer);

  final Timer _timer;

  @override
  void cancel() {
    _timer.cancel();
  }
}
