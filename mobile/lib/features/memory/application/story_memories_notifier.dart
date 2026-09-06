import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_canonical_order.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
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
  int _refreshRevision = 0;

  @override
  Future<StoryMemoriesState> build() async {
    _invalidateRefresh();
    return _load(_storyId, ref.watch(memoryRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<StoryMemoriesState>();
    final retryRevision = ++_refreshRevision;
    final result = await AsyncValue.guard<StoryMemoriesState>(() async {
      return _load(_storyId, ref.read(memoryRepositoryProvider));
    });
    if (!_isCurrentRefresh(retryRevision)) {
      return;
    }

    state = result;
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
    final refreshRevision = ++_refreshRevision;

    try {
      final memories = await ref
          .read(memoryRepositoryProvider)
          .getMemories(_storyId);
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<StoryMemoriesState>(
        StoryMemoriesState(memoryReadModels: memories),
      );
    } on MemoryApplicationException catch (error) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<StoryMemoriesState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

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

    final existing = _readModelByMemoryId(
      currentState.memoryReadModels,
      memory.id,
    );
    final readModel = existing == null
        ? MemoryReadModel.fromMemory(memory)
        : existing.withMemoryMutation(memory);

    _upsertReadModel(readModel);
  }

  void upsertAuthoritativeRead(MemoryReadModel readModel) {
    _upsertReadModel(readModel);
  }

  void _upsertReadModel(MemoryReadModel readModel) {
    final currentState = _currentState;
    if (currentState == null ||
        currentState.hasLoadFailure ||
        readModel.memory.storyId != _storyId) {
      return;
    }

    final memories = currentState.memoryReadModels
        .where((existing) => existing.memory.id != readModel.memory.id)
        .toList();
    memories.add(readModel);
    memories.sort(compareMemoryReadModelsCanonical);

    _invalidateRefresh();
    state = AsyncData<StoryMemoriesState>(
      currentState.copyWith(
        memoryReadModels: memories,
        isRefreshing: false,
      ),
    );
  }

  void removeMemoryById(String memoryId) {
    final currentState = _currentState;
    if (currentState == null || currentState.hasLoadFailure) {
      return;
    }

    final memories = currentState.memoryReadModels
        .where((memory) => memory.memory.id != memoryId)
        .toList();
    if (memories.length == currentState.memoryReadModels.length) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<StoryMemoriesState>(
      currentState.copyWith(
        memoryReadModels: memories,
        isRefreshing: false,
      ),
    );
  }

  MemoryReadModel? _readModelByMemoryId(
    List<MemoryReadModel> memories,
    String memoryId,
  ) {
    for (final memory in memories) {
      if (memory.memory.id == memoryId) {
        return memory;
      }
    }

    return null;
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
      return StoryMemoriesState(memoryReadModels: memories);
    } on MemoryApplicationException catch (error) {
      return StoryMemoriesState(loadFailure: error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<StoryMemoriesState>;

  void _invalidateRefresh() {
    _refreshRevision += 1;
  }

  bool _isCurrentRefresh(int refreshRevision) {
    return ref.mounted && _refreshRevision == refreshRevision;
  }

  StoryMemoriesState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StoryMemoriesState>) {
      return currentState.value;
    }

    return null;
  }
}
