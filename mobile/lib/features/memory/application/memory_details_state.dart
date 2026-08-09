import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class MemoryDetailsState {
  factory MemoryDetailsState.loaded({
    required Memory memory,
    bool isRefreshing = false,
    MemoryFailure? refreshFailure,
  }) {
    return MemoryDetailsState._(
      memory: memory,
      isRefreshing: isRefreshing,
      loadFailure: null,
      refreshFailure: refreshFailure,
    );
  }

  factory MemoryDetailsState.loadFailure(MemoryFailure failure) {
    return MemoryDetailsState._(
      memory: null,
      isRefreshing: false,
      loadFailure: failure,
      refreshFailure: null,
    );
  }

  const MemoryDetailsState._({
    required this.memory,
    required this.isRefreshing,
    required this.loadFailure,
    required this.refreshFailure,
  });

  final Memory? memory;
  final bool isRefreshing;
  final MemoryFailure? loadFailure;
  final MemoryFailure? refreshFailure;

  bool get hasMemory => memory != null;

  bool get isLoaded => memory != null && loadFailure == null;

  bool get hasLoadFailure => loadFailure != null;

  MemoryDetailsState copyWith({
    Memory? memory,
    bool? isRefreshing,
    MemoryFailure? loadFailure,
    MemoryFailure? refreshFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return MemoryDetailsState._(
      memory: memory ?? this.memory,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryDetailsState &&
            memory == other.memory &&
            isRefreshing == other.isRefreshing &&
            loadFailure == other.loadFailure &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        memory,
        isRefreshing,
        loadFailure,
        refreshFailure,
      );

  @override
  String toString() {
    return 'MemoryDetailsState(hasMemory: $hasMemory, '
        'isRefreshing: $isRefreshing, '
        'hasLoadFailure: ${loadFailure != null}, '
        'hasRefreshFailure: ${refreshFailure != null})';
  }
}
