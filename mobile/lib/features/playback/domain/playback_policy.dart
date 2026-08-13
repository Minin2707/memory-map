final class PlaybackPolicy {
  const PlaybackPolicy({
    this.presentationDuration = const Duration(seconds: 5),
    this.cameraDuration = const Duration(seconds: 2),
  });

  final Duration presentationDuration;
  final Duration cameraDuration;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackPolicy &&
            presentationDuration == other.presentationDuration &&
            cameraDuration == other.cameraDuration;
  }

  @override
  int get hashCode => Object.hash(presentationDuration, cameraDuration);

  @override
  String toString() {
    return 'PlaybackPolicy(presentationDuration: $presentationDuration, '
        'cameraDuration: $cameraDuration)';
  }
}

