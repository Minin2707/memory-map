import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_canonical_order.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';

final storyMemoriesProvider =
    AsyncNotifierProvider.family<StoryMemoriesNotifier, StoryMemoriesState,
        String>(
  StoryMemoriesNotifier.new,
  retry: (retryCount, error) => null,
);

final class StoryMemoriesNotifier extends AsyncNotifier<StoryMemoriesState> {
  StoryMemoriesNotifier(this._storyId);

  final String _storyId;

  @override
  Future<StoryMemoriesState> build() async {
    return _load(_storyId, ref.watch(memoryRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<StoryMemoriesState>();
    state = await AsyncValue.guard<StoryMemoriesState>(() async {
      return _load(_storyId, ref.read(memoryRepositoryProvider));
    });
  }

  Future<void> refreshMemories() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        currentState.hasLoadFailure ||
        currentState.isRefreshing) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<StoryMemoriesState>(refreshingState);

    try {
      final memories = await ref
          .read(memoryRepositoryProvider)
          .getMemories(_storyId);
      state = AsyncData<StoryMemoriesState>(
        StoryMemoriesState(memories: memories),
      );
    } on MemoryApplicationException catch (error) {
      state = AsyncData<StoryMemoriesState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<StoryMemoriesState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<StoryMemoriesState>(error, stackTrace);
    }
  }

  void upsertMemory(Memory memory) {
    final currentState = _currentState;
    if (currentState == null ||
        currentState.hasLoadFailure ||
        memory.storyId != _storyId) {
      return;
    }

    final memories = currentState.memories
        .where((existing) => existing.id != memory.id)
        .toList();
    memories.add(memory);
    memories.sort(compareMemoriesCanonical);

    state = AsyncData<StoryMemoriesState>(
      currentState.copyWith(memories: memories),
    );
  }

  void removeMemoryById(String memoryId) {
    final currentState = _currentState;
    if (currentState == null || currentState.hasLoadFailure) {
      return;
    }

    final memories = currentState.memories
        .where((memory) => memory.id != memoryId)
        .toList();
    if (memories.length == currentState.memories.length) {
      return;
    }

    state = AsyncData<StoryMemoriesState>(
      currentState.copyWith(memories: memories),
    );
  }

  Future<StoryMemoriesState> _load(
    String storyId,
    MemoryRepository repository,
  ) async {
    if (storyId.trim().isEmpty) {
      return StoryMemoriesState(
        loadFailure: const MemoryValidationFailure(),
      );
    }

    try {
      final memories = await repository.getMemories(storyId);
      return StoryMemoriesState(memories: memories);
    } on MemoryApplicationException catch (error) {
      return StoryMemoriesState(loadFailure: error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<StoryMemoriesState>;

  StoryMemoriesState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StoryMemoriesState>) {
      return currentState.value;
    }

    return null;
  }
}
