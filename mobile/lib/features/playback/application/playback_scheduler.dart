abstract interface class PlaybackScheduler {
  PlaybackScheduledTask schedule(
    Duration delay,
    void Function() callback,
  );
}

abstract interface class PlaybackScheduledTask {
  void cancel();
}
