import 'package:memory_map/features/memory/domain/memory_read_model.dart';

final class StoryTimelineSection {
  StoryTimelineSection({
    required this.year,
    required List<MemoryReadModel> memories,
  }) : memories = List<MemoryReadModel>.unmodifiable(memories);

  final int year;
  final List<MemoryReadModel> memories;

  bool get isEmpty => memories.isEmpty;

  int get memoryCount => memories.length;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryTimelineSection &&
            year == other.year &&
            _listEquals(memories, other.memories);
  }

  @override
  int get hashCode => Object.hash(year, Object.hashAll(memories));

  @override
  String toString() {
    return 'StoryTimelineSection(year: $year, memoryCount: $memoryCount)';
  }

  static bool _listEquals<T>(List<T> left, List<T> right) {
    if (identical(left, right)) {
      return true;
    }

    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
