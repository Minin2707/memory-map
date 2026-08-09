import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class StoryMemoriesState {
  factory StoryMemoriesState({
    List<Memory> memories = const <Memory>[],
    MemoryFailure? loadFailure,
    bool isRefreshing = false,
    MemoryFailure? refreshFailure,
  }) {
    return StoryMemoriesState._(
      memories: List<Memory>.unmodifiable(memories),
      loadFailure: loadFailure,
      isRefreshing: isRefreshing,
      refreshFailure: refreshFailure,
    );
  }

  const StoryMemoriesState._({
    required this.memories,
    required this.loadFailure,
    required this.isRefreshing,
    required this.refreshFailure,
  });

  final List<Memory> memories;
  final MemoryFailure? loadFailure;
  final bool isRefreshing;
  final MemoryFailure? refreshFailure;

  bool get hasMemories => memories.isNotEmpty;

  bool get hasLoadFailure => loadFailure != null;

  bool get isLoaded => loadFailure == null;

  StoryMemoriesState copyWith({
    List<Memory>? memories,
    MemoryFailure? loadFailure,
    bool? isRefreshing,
    MemoryFailure? refreshFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return StoryMemoriesState(
      memories: memories ?? this.memories,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryMemoriesState &&
            _listEquals(memories, other.memories) &&
            loadFailure == other.loadFailure &&
            isRefreshing == other.isRefreshing &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(memories),
        loadFailure,
        isRefreshing,
        refreshFailure,
      );

  @override
  String toString() {
    return 'StoryMemoriesState(memoryCount: ${memories.length}, '
        'hasMemories: $hasMemories, isRefreshing: $isRefreshing, '
        'hasLoadFailure: ${loadFailure != null}, '
        'hasRefreshFailure: ${refreshFailure != null})';
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
