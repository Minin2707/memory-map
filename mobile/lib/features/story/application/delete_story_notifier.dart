import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/delete_story_state.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_summary_reconciler.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';

final deleteStoryProvider = AsyncNotifierProvider.autoDispose
    .family<DeleteStoryNotifier, DeleteStoryState, String>(
  DeleteStoryNotifier.new,
  retry: (retryCount, error) => null,
);

final class DeleteStoryNotifier extends AsyncNotifier<DeleteStoryState> {
  DeleteStoryNotifier(this._storyId);

  final String _storyId;
  int _operationRevision = 0;

  @override
  Future<DeleteStoryState> build() async {
    _operationRevision += 1;
    return const DeleteStoryState();
  }

  Future<bool> deleteStory() async {
    if (!ref.mounted) {
      return false;
    }

    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isDeleting) {
      return false;
    }

    if (_storyId.trim().isEmpty) {
      state = AsyncData<DeleteStoryState>(
        currentState.copyWith(
          isDeleting: false,
          deleteFailure: const StoryValidationFailure(),
        ),
      );
      return false;
    }

    final deletingState = currentState.copyWith(
      isDeleting: true,
      clearDeleteFailure: true,
    );
    final operationRevision = _nextOperationRevision();
    state = AsyncData<DeleteStoryState>(deletingState);

    try {
      await ref.read(storyRepositoryProvider).deleteStory(storyId: _storyId);
      if (!_isActiveOperation(operationRevision, deletingState)) {
        return false;
      }

      ref.read(storySummaryReconcilerProvider).removeStory(_storyId);
      state = const AsyncData<DeleteStoryState>(DeleteStoryState());
      return true;
    } on StoryApplicationException catch (error) {
      if (!_isActiveOperation(operationRevision, deletingState)) {
        return false;
      }

      state = AsyncData<DeleteStoryState>(
        deletingState.copyWith(
          isDeleting: false,
          deleteFailure: error.failure,
        ),
      );
      return false;
    } on Object catch (error, stackTrace) {
      if (!_isActiveOperation(operationRevision, deletingState)) {
        return false;
      }

      state = AsyncData<DeleteStoryState>(
        deletingState.copyWith(isDeleting: false),
      );
      state = AsyncError<DeleteStoryState>(error, stackTrace);
      return false;
    }
  }

  void reset() {
    if (!ref.mounted) {
      return;
    }

    _operationRevision += 1;
    state = const AsyncData<DeleteStoryState>(DeleteStoryState());
  }

  bool get _isLoading => state is AsyncLoading<DeleteStoryState>;

  DeleteStoryState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<DeleteStoryState>) {
      return currentState.value;
    }

    return null;
  }

  int _nextOperationRevision() {
    _operationRevision += 1;
    return _operationRevision;
  }

  bool _isActiveOperation(
    int operationRevision,
    DeleteStoryState operationState,
  ) {
    if (!ref.mounted || _operationRevision != operationRevision) {
      return false;
    }

    final currentState = _currentState;
    return currentState == operationState;
  }
}
