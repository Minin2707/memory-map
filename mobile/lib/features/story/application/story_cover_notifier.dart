import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_cover_state.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final storyCoverProvider =
    AsyncNotifierProvider.autoDispose.family<StoryCoverNotifier,
        StoryCoverState, String>(
  StoryCoverNotifier.new,
  retry: (retryCount, error) => null,
);

final class StoryCoverNotifier extends AsyncNotifier<StoryCoverState> {
  StoryCoverNotifier(this._storyId);

  final String _storyId;
  int _operationRevision = 0;

  @override
  Future<StoryCoverState> build() async {
    _operationRevision += 1;
    return const StoryCoverState();
  }

  Future<UserStory?> uploadStoryCover(PreparedPhotoUpload photo) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isBusy) {
      return null;
    }

    if (_storyId.trim().isEmpty) {
      state = AsyncData<StoryCoverState>(
        currentState.copyWith(
          isUploading: false,
          failure: const StoryValidationFailure(),
        ),
      );
      return null;
    }

    final uploadingState = currentState.copyWith(
      isUploading: true,
      clearFailure: true,
    );
    final operationRevision = _nextOperationRevision();
    state = AsyncData<StoryCoverState>(uploadingState);

    try {
      final userStory = await ref.read(storyRepositoryProvider)
          .uploadStoryCover(storyId: _storyId, photo: photo);
      if (!_isActiveOperation(operationRevision, uploadingState)) {
        return null;
      }

      _applyAuthoritativeRead(userStory);
      state = const AsyncData<StoryCoverState>(StoryCoverState());
      return userStory;
    } on StoryApplicationException catch (error) {
      if (!_isActiveOperation(operationRevision, uploadingState)) {
        return null;
      }

      state = AsyncData<StoryCoverState>(
        uploadingState.copyWith(
          isUploading: false,
          failure: error.failure,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      if (!_isActiveOperation(operationRevision, uploadingState)) {
        return null;
      }

      state = AsyncData<StoryCoverState>(
        uploadingState.copyWith(isUploading: false),
      );
      state = AsyncError<StoryCoverState>(error, stackTrace);
      return null;
    }
  }

  Future<UserStory?> removeStoryCover() async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isBusy) {
      return null;
    }

    if (_storyId.trim().isEmpty) {
      state = AsyncData<StoryCoverState>(
        currentState.copyWith(
          isRemoving: false,
          failure: const StoryValidationFailure(),
        ),
      );
      return null;
    }

    final removingState = currentState.copyWith(
      isRemoving: true,
      clearFailure: true,
    );
    final operationRevision = _nextOperationRevision();
    state = AsyncData<StoryCoverState>(removingState);

    try {
      final userStory = await ref.read(storyRepositoryProvider)
          .removeStoryCover(storyId: _storyId);
      if (!_isActiveOperation(operationRevision, removingState)) {
        return null;
      }

      _applyAuthoritativeRead(userStory);
      state = const AsyncData<StoryCoverState>(StoryCoverState());
      return userStory;
    } on StoryApplicationException catch (error) {
      if (!_isActiveOperation(operationRevision, removingState)) {
        return null;
      }

      state = AsyncData<StoryCoverState>(
        removingState.copyWith(
          isRemoving: false,
          failure: error.failure,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      if (!_isActiveOperation(operationRevision, removingState)) {
        return null;
      }

      state = AsyncData<StoryCoverState>(
        removingState.copyWith(isRemoving: false),
      );
      state = AsyncError<StoryCoverState>(error, stackTrace);
      return null;
    }
  }

  void reset() {
    _operationRevision += 1;
    state = const AsyncData<StoryCoverState>(StoryCoverState());
  }

  void _applyAuthoritativeRead(UserStory userStory) {
    final stories = storiesNotifierProvider;
    if (ref.exists(stories)) {
      ref.read(stories.notifier).applyAuthoritativeRead(userStory);
    }

    final details = storyDetailsProvider(userStory.story.id);
    if (ref.exists(details)) {
      ref.read(details.notifier).applyAuthoritativeRead(userStory);
    }
  }

  bool get _isLoading => state is AsyncLoading<StoryCoverState>;

  StoryCoverState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StoryCoverState>) {
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
    StoryCoverState operationState,
  ) {
    if (!ref.mounted || _operationRevision != operationRevision) {
      return false;
    }

    final currentState = _currentState;
    return currentState == operationState;
  }
}
