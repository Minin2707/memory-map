import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/edit_story_state.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final editStoryProvider =
    AsyncNotifierProvider.family<EditStoryNotifier, EditStoryState, String>(
  EditStoryNotifier.new,
  retry: (retryCount, error) => null,
);

final class EditStoryNotifier extends AsyncNotifier<EditStoryState> {
  EditStoryNotifier(this._storyId);

  final String _storyId;

  @override
  Future<EditStoryState> build() async {
    return const EditStoryState();
  }

  Future<UserStory?> save(UpdateStoryInput input) async {
    if (input.storyId != _storyId) {
      throw ArgumentError('input storyId must match provider storyId');
    }

    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isSaving) {
      return null;
    }

    final savingState = currentState.copyWith(
      isSaving: true,
      clearSaveFailure: true,
    );
    state = AsyncData<EditStoryState>(savingState);

    try {
      final updatedStory = await ref.read(storyRepositoryProvider).updateStory(
            input,
          );
      state = AsyncData<EditStoryState>(
        savingState.copyWith(
          isSaving: false,
          clearSaveFailure: true,
        ),
      );
      return updatedStory;
    } on StoryApplicationException catch (error) {
      state = AsyncData<EditStoryState>(
        savingState.copyWith(
          isSaving: false,
          saveFailure: error.failure,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<EditStoryState>(
        savingState.copyWith(isSaving: false),
      );
      state = AsyncError<EditStoryState>(error, stackTrace);
      return null;
    }
  }

  bool get _isLoading => state is AsyncLoading<EditStoryState>;

  EditStoryState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<EditStoryState>) {
      return currentState.value;
    }

    return null;
  }
}
