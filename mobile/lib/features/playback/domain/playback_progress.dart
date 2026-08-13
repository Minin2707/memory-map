final class PlaybackProgress {
  factory PlaybackProgress({
    required int currentPosition,
    required int total,
  }) {
    if (currentPosition < 0) {
      throw ArgumentError('currentPosition must not be negative');
    }

    if (total < 0) {
      throw ArgumentError('total must not be negative');
    }

    if (currentPosition > total) {
      throw ArgumentError('currentPosition must not exceed total');
    }

    return PlaybackProgress._(
      currentPosition: currentPosition,
      total: total,
    );
  }

  const PlaybackProgress._({
    required this.currentPosition,
    required this.total,
  });

  final int currentPosition;
  final int total;

  double get fraction {
    if (total == 0) {
      return 0;
    }

    return currentPosition / total;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackProgress &&
            currentPosition == other.currentPosition &&
            total == other.total;
  }

  @override
  int get hashCode => Object.hash(currentPosition, total);

  @override
  String toString() {
    return 'PlaybackProgress(currentPosition: $currentPosition, total: $total)';
  }
}

