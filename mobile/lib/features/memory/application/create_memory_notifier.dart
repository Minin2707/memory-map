import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/create_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/story/application/story_summary_reconciler.dart';

final createMemoryProvider = AsyncNotifierProvider.autoDispose
    .family<CreateMemoryNotifier, CreateMemoryState, String>(
  CreateMemoryNotifier.new,
  retry: (retryCount, error) => null,
);

final class CreateMemoryNotifier extends AsyncNotifier<CreateMemoryState> {
  CreateMemoryNotifier(this._storyId);

  final String _storyId;

  @override
  Future<CreateMemoryState> build() async {
    return const CreateMemoryState();
  }

  Future<Memory?> submit(CreateMemoryInput input) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isSubmitting) {
      return null;
    }

    if (input.storyId != _storyId) {
      state = AsyncData<CreateMemoryState>(
        currentState.copyWith(
          isSubmitting: false,
          failure: const MemoryValidationFailure(),
        ),
      );
      return null;
    }

    final submittingState = currentState.copyWith(
      isSubmitting: true,
      clearFailure: true,
    );
    state = AsyncData<CreateMemoryState>(submittingState);

    try {
      final memory = await ref.read(memoryRepositoryProvider).createMemory(
            input,
          );
      if (memory.storyId != _storyId) {
        throw StateError('Created memory belongs to a different story');
      }

      _upsertIntoLoadedStoryMemories(memory);
      await ref
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory(_storyId);
      if (!ref.mounted) {
        return null;
      }

      state = const AsyncData<CreateMemoryState>(CreateMemoryState());
      return memory;
    } on MemoryApplicationException catch (error) {
      state = AsyncData<CreateMemoryState>(
        submittingState.copyWith(
          isSubmitting: false,
          failure: error.failure,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<CreateMemoryState>(
        submittingState.copyWith(isSubmitting: false),
      );
      state = AsyncError<CreateMemoryState>(error, stackTrace);
      return null;
    }
  }

  void reset() {
    state = const AsyncData<CreateMemoryState>(CreateMemoryState());
  }

  void _upsertIntoLoadedStoryMemories(Memory memory) {
    final storyMemories = storyMemoriesProvider(_storyId);
    if (!ref.exists(storyMemories)) {
      return;
    }

    ref.read(storyMemories.notifier).upsertMemory(memory);
  }

  bool get _isLoading => state is AsyncLoading<CreateMemoryState>;

  CreateMemoryState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<CreateMemoryState>) {
      return currentState.value;
    }

    return null;
  }
}
