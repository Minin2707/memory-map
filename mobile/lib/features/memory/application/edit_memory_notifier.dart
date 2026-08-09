import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/edit_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

final editMemoryProvider = AsyncNotifierProvider.autoDispose
    .family<EditMemoryNotifier, EditMemoryState, String>(
  EditMemoryNotifier.new,
  retry: (retryCount, error) => null,
);

final class EditMemoryNotifier extends AsyncNotifier<EditMemoryState> {
  EditMemoryNotifier(this._memoryId);

  final String _memoryId;

  @override
  Future<EditMemoryState> build() async {
    return const EditMemoryState();
  }

  Future<Memory?> save(UpdateMemoryInput input) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isSaving) {
      return null;
    }

    if (input.memoryId != _memoryId) {
      state = AsyncData<EditMemoryState>(
        currentState.copyWith(
          isSaving: false,
          saveFailure: const MemoryValidationFailure(),
        ),
      );
      return null;
    }

    final savingState = currentState.copyWith(
      isSaving: true,
      clearSaveFailure: true,
    );
    state = AsyncData<EditMemoryState>(savingState);

    try {
      final updatedMemory = await ref.read(memoryRepositoryProvider).updateMemory(
            input,
          );
      if (updatedMemory.id != _memoryId) {
        throw StateError('Updated memory has an unexpected id');
      }

      _synchronizeLoadedMemoryDetails(updatedMemory);
      _upsertIntoLoadedStoryMemories(updatedMemory);
      state = const AsyncData<EditMemoryState>(EditMemoryState());
      return updatedMemory;
    } on MemoryApplicationException catch (error) {
      state = AsyncData<EditMemoryState>(
        savingState.copyWith(
          isSaving: false,
          saveFailure: error.failure,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<EditMemoryState>(
        savingState.copyWith(isSaving: false),
      );
      state = AsyncError<EditMemoryState>(error, stackTrace);
      return null;
    }
  }

  void reset() {
    state = const AsyncData<EditMemoryState>(EditMemoryState());
  }

  void _synchronizeLoadedMemoryDetails(Memory updatedMemory) {
    final details = memoryDetailsProvider(_memoryId);
    if (!ref.exists(details)) {
      return;
    }

    final currentDetails = ref.read(details).asData?.value.memory;
    if (currentDetails != null &&
        currentDetails.storyId != updatedMemory.storyId) {
      throw StateError('Updated memory belongs to a different story');
    }

    ref.read(details.notifier).applyUpdatedMemory(updatedMemory);
  }

  void _upsertIntoLoadedStoryMemories(Memory updatedMemory) {
    final storyMemories = storyMemoriesProvider(updatedMemory.storyId);
    if (!ref.exists(storyMemories)) {
      return;
    }

    ref.read(storyMemories.notifier).upsertMemory(updatedMemory);
  }

  bool get _isLoading => state is AsyncLoading<EditMemoryState>;

  EditMemoryState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<EditMemoryState>) {
      return currentState.value;
    }

    return null;
  }
}
