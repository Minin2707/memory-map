enum PlaybackAudioStatus {
  idle,
  preparing,
  ready,
  playing,
  paused,
  completed,
  failed,
}

sealed class PlaybackAudioFailure {
  const PlaybackAudioFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackAudioFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class PlaybackAudioValidationFailure extends PlaybackAudioFailure {
  const PlaybackAudioValidationFailure();
}

final class PlaybackAudioAuthenticationFailure extends PlaybackAudioFailure {
  const PlaybackAudioAuthenticationFailure();
}

final class PlaybackAudioUnavailableFailure extends PlaybackAudioFailure {
  const PlaybackAudioUnavailableFailure();
}

final class UnknownPlaybackAudioFailure extends PlaybackAudioFailure {
  const UnknownPlaybackAudioFailure();
}

final class PlaybackAudioState {
  factory PlaybackAudioState.idle() {
    return const PlaybackAudioState._(
      status: PlaybackAudioStatus.idle,
      failure: null,
    );
  }

  factory PlaybackAudioState.preparing() {
    return const PlaybackAudioState._(
      status: PlaybackAudioStatus.preparing,
      failure: null,
    );
  }

  factory PlaybackAudioState.ready() {
    return const PlaybackAudioState._(
      status: PlaybackAudioStatus.ready,
      failure: null,
    );
  }

  factory PlaybackAudioState.playing() {
    return const PlaybackAudioState._(
      status: PlaybackAudioStatus.playing,
      failure: null,
    );
  }

  factory PlaybackAudioState.paused() {
    return const PlaybackAudioState._(
      status: PlaybackAudioStatus.paused,
      failure: null,
    );
  }

  factory PlaybackAudioState.completed() {
    return const PlaybackAudioState._(
      status: PlaybackAudioStatus.completed,
      failure: null,
    );
  }

  factory PlaybackAudioState.failed(PlaybackAudioFailure failure) {
    return PlaybackAudioState._(
      status: PlaybackAudioStatus.failed,
      failure: failure,
    );
  }

  const PlaybackAudioState._({
    required this.status,
    required this.failure,
  });

  final PlaybackAudioStatus status;
  final PlaybackAudioFailure? failure;

  bool get isIdle => status == PlaybackAudioStatus.idle;

  bool get isPreparing => status == PlaybackAudioStatus.preparing;

  bool get isReady => status == PlaybackAudioStatus.ready;

  bool get isPlaying => status == PlaybackAudioStatus.playing;

  bool get isPaused => status == PlaybackAudioStatus.paused;

  bool get isCompleted => status == PlaybackAudioStatus.completed;

  bool get hasFailure => failure != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackAudioState &&
            status == other.status &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(status, failure);

  @override
  String toString() {
    return 'PlaybackAudioState(status: $status, hasFailure: $hasFailure)';
  }
}
