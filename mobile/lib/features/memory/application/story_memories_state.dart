import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class StoryMemoriesState {
  factory StoryMemoriesState({
    List<Memory> memories = const <Memory>[],
    List<MemoryReadModel>? memoryReadModels,
    MemoryFailure? loadFailure,
    bool isRefreshing = false,
    MemoryFailure? refreshFailure,
  }) {
    final readModels = memoryReadModels ??
        memories.map(MemoryReadModel.fromMemory).toList(growable: false);

    return StoryMemoriesState._(
      memoryReadModels: List<MemoryReadModel>.unmodifiable(readModels),
      loadFailure: loadFailure,
      isRefreshing: isRefreshing,
      refreshFailure: refreshFailure,
    );
  }

  const StoryMemoriesState._({
    required this.memoryReadModels,
    required this.loadFailure,
    required this.isRefreshing,
    required this.refreshFailure,
  });

  final List<MemoryReadModel> memoryReadModels;
  final MemoryFailure? loadFailure;
  final bool isRefreshing;
  final MemoryFailure? refreshFailure;

  bool get hasMemories => memoryReadModels.isNotEmpty;

  List<Memory> get memories {
    return List<Memory>.unmodifiable(
      memoryReadModels.map((item) => item.memory),
    );
  }

  bool get hasLoadFailure => loadFailure != null;

  bool get isLoaded => loadFailure == null;

  StoryMemoriesState copyWith({
    List<Memory>? memories,
    List<MemoryReadModel>? memoryReadModels,
    MemoryFailure? loadFailure,
    bool? isRefreshing,
    MemoryFailure? refreshFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return StoryMemoriesState(
      memories: memories ?? const <Memory>[],
      memoryReadModels: memoryReadModels ??
          (memories == null
              ? this.memoryReadModels
              : memories.map(MemoryReadModel.fromMemory).toList()),
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
            _listEquals(memoryReadModels, other.memoryReadModels) &&
            loadFailure == other.loadFailure &&
            isRefreshing == other.isRefreshing &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(memoryReadModels),
        loadFailure,
        isRefreshing,
        refreshFailure,
      );

  @override
  String toString() {
    return 'StoryMemoriesState(memoryCount: ${memoryReadModels.length}, '
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
