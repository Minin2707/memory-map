import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/delete_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/story/application/story_summary_reconciler.dart';

final deleteMemoryProvider = AsyncNotifierProvider.autoDispose
    .family<DeleteMemoryNotifier, DeleteMemoryState, String>(
  DeleteMemoryNotifier.new,
  retry: (retryCount, error) => null,
);

final class DeleteMemoryNotifier extends AsyncNotifier<DeleteMemoryState> {
  DeleteMemoryNotifier(this._memoryId);

  final String _memoryId;

  @override
  Future<DeleteMemoryState> build() async {
    return const DeleteMemoryState();
  }

  Future<bool> deleteMemory(Memory memory) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isDeleting) {
      return false;
    }

    if (memory.id != _memoryId) {
      state = AsyncData<DeleteMemoryState>(
        currentState.copyWith(
          isDeleting: false,
          deleteFailure: const MemoryValidationFailure(),
        ),
      );
      return false;
    }

    late final DeleteMemoryInput input;
    try {
      input = DeleteMemoryInput(memoryId: memory.id);
    } on ArgumentError {
      state = AsyncData<DeleteMemoryState>(
        currentState.copyWith(
          isDeleting: false,
          deleteFailure: const MemoryValidationFailure(),
        ),
      );
      return false;
    }

    final deletingState = currentState.copyWith(
      isDeleting: true,
      clearDeleteFailure: true,
    );
    state = AsyncData<DeleteMemoryState>(deletingState);

    try {
      await ref.read(memoryRepositoryProvider).deleteMemory(input);
      _removeFromLoadedStoryMemories(memory);
      await ref
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory(memory.storyId);
      if (!ref.mounted) {
        return false;
      }

      state = const AsyncData<DeleteMemoryState>(DeleteMemoryState());
      return true;
    } on MemoryApplicationException catch (error) {
      state = AsyncData<DeleteMemoryState>(
        deletingState.copyWith(
          isDeleting: false,
          deleteFailure: error.failure,
        ),
      );
      return false;
    } on Object catch (error, stackTrace) {
      state = AsyncData<DeleteMemoryState>(
        deletingState.copyWith(isDeleting: false),
      );
      state = AsyncError<DeleteMemoryState>(error, stackTrace);
      return false;
    }
  }

  void reset() {
    state = const AsyncData<DeleteMemoryState>(DeleteMemoryState());
  }

  void _removeFromLoadedStoryMemories(Memory memory) {
    final storyMemories = storyMemoriesProvider(memory.storyId);
    if (!ref.exists(storyMemories)) {
      return;
    }

    ref.read(storyMemories.notifier).removeMemoryById(memory.id);
  }

  bool get _isLoading => state is AsyncLoading<DeleteMemoryState>;

  DeleteMemoryState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<DeleteMemoryState>) {
      return currentState.value;
    }

    return null;
  }
}
