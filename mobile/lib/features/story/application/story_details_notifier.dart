import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final storyDetailsProvider = AsyncNotifierProvider.family<
    StoryDetailsNotifier, StoryDetailsState, String>(
  StoryDetailsNotifier.new,
  retry: (retryCount, error) => null,
);

final class StoryDetailsNotifier extends AsyncNotifier<StoryDetailsState> {
  StoryDetailsNotifier(this._storyId);

  final String _storyId;

  @override
  Future<StoryDetailsState> build() async {
    return _load(_storyId, ref.watch(storyRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<StoryDetailsState>();
    state = await AsyncValue.guard<StoryDetailsState>(() async {
      return _load(_storyId, ref.read(storyRepositoryProvider));
    });
  }

  Future<void> refreshStory() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.isRefreshing) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<StoryDetailsState>(refreshingState);

    try {
      final userStory = await ref.read(storyRepositoryProvider).getStory(
            _storyId,
          );
      state = AsyncData<StoryDetailsState>(
        StoryDetailsState.loaded(userStory: userStory),
      );
    } on StoryApplicationException catch (error) {
      state = AsyncData<StoryDetailsState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<StoryDetailsState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<StoryDetailsState>(error, stackTrace);
    }
  }

  void applyUpdatedStory(UserStory updatedStory) {
    final currentState = _currentState;
    final currentStory = currentState?.userStory;
    if (currentState == null ||
        currentStory == null ||
        currentStory.story.id != updatedStory.story.id) {
      return;
    }

    state = AsyncData<StoryDetailsState>(
      currentState.copyWith(
        userStory: updatedStory,
        clearRefreshFailure: true,
      ),
    );
  }

  Future<StoryDetailsState> _load(
    String storyId,
    StoryRepository repository,
  ) async {
    if (storyId.trim().isEmpty) {
      return StoryDetailsState.loadFailure(const StoryNotFound());
    }

    try {
      return StoryDetailsState.loaded(
        userStory: await repository.getStory(storyId),
      );
    } on StoryApplicationException catch (error) {
      return StoryDetailsState.loadFailure(error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<StoryDetailsState>;

  StoryDetailsState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StoryDetailsState>) {
      return currentState.value;
    }

    return null;
  }
}
