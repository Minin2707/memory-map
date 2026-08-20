import 'package:memory_map/features/memory/domain/memory_read_model.dart';

final class StoryMemoriesYearSection {
  StoryMemoriesYearSection({
    required this.year,
    required List<MemoryReadModel> memories,
  }) : memories = List<MemoryReadModel>.unmodifiable(memories);

  final int year;
  final List<MemoryReadModel> memories;

  int get memoryCount => memories.length;

  bool get isEmpty => memories.isEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryMemoriesYearSection &&
            year == other.year &&
            _listEquals(memories, other.memories);
  }

  @override
  int get hashCode => Object.hash(year, Object.hashAll(memories));

  @override
  String toString() {
    return 'StoryMemoriesYearSection(year: $year, memoryCount: $memoryCount)';
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
