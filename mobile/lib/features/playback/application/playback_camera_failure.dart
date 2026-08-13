final class PlaybackCameraFailure {
  factory PlaybackCameraFailure({
    required int revision,
  }) {
    if (revision < 0) {
      throw ArgumentError('revision must not be negative');
    }

    return PlaybackCameraFailure._(revision: revision);
  }

  const PlaybackCameraFailure._({
    required this.revision,
  });

  final int revision;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackCameraFailure && revision == other.revision;
  }

  @override
  int get hashCode => revision.hashCode;

  @override
  String toString() => 'PlaybackCameraFailure(hasRevision: true)';
}
