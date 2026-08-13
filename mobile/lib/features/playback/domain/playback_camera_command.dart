import 'package:memory_map/features/map/domain/map_coordinate.dart';

final class PlaybackCameraCommand {
  factory PlaybackCameraCommand({
    required int revision,
    required int memoryIndex,
    required MapCoordinate target,
    required Duration duration,
  }) {
    if (revision < 0) {
      throw ArgumentError('revision must not be negative');
    }

    if (memoryIndex < 0) {
      throw ArgumentError('memoryIndex must not be negative');
    }

    if (duration.isNegative || duration == Duration.zero) {
      throw ArgumentError('duration must be positive');
    }

    return PlaybackCameraCommand._(
      revision: revision,
      memoryIndex: memoryIndex,
      target: target,
      duration: duration,
    );
  }

  const PlaybackCameraCommand._({
    required this.revision,
    required this.memoryIndex,
    required this.target,
    required this.duration,
  });

  final int revision;
  final int memoryIndex;
  final MapCoordinate target;
  final Duration duration;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackCameraCommand &&
            revision == other.revision &&
            memoryIndex == other.memoryIndex &&
            target == other.target &&
            duration == other.duration;
  }

  @override
  int get hashCode => Object.hash(revision, memoryIndex, target, duration);

  @override
  String toString() {
    return 'PlaybackCameraCommand(revision: $revision, '
        'memoryIndex: $memoryIndex, hasTarget: true, duration: $duration)';
  }
}

