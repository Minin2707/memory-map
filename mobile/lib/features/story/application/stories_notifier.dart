import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/stories_state.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final storiesNotifierProvider =
    AsyncNotifierProvider<StoriesNotifier, StoriesState>(
  StoriesNotifier.new,
  retry: (retryCount, error) => null,
);

final class StoriesNotifier extends AsyncNotifier<StoriesState> {
  @override
  Future<StoriesState> build() async {
    return _load(ref.watch(storyRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<StoriesState>();
    state = await AsyncValue.guard<StoriesState>(() async {
      return _load(ref.read(storyRepositoryProvider));
    });
  }

  Future<void> refreshStories() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        currentState.hasLoadFailure ||
        currentState.isRefreshing ||
        currentState.isCreating) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<StoriesState>(refreshingState);

    try {
      final stories = await ref.read(storyRepositoryProvider).getStories();
      state = AsyncData<StoriesState>(StoriesState(stories: stories));
    } on StoryApplicationException catch (error) {
      state = AsyncData<StoriesState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<StoriesState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<StoriesState>(error, stackTrace);
    }
  }

  Future<Story?> createStory({
    required String title,
    String? description,
  }) async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        currentState.hasLoadFailure ||
        currentState.isRefreshing ||
        currentState.isCreating) {
      return null;
    }

    final creatingState = currentState.copyWith(
      isCreating: true,
      clearCreateFailure: true,
    );
    state = AsyncData<StoriesState>(creatingState);

    late final Story createdStory;
    try {
      createdStory = await ref.read(storyRepositoryProvider).createStory(
            title: title,
            description: description,
          );
    } on StoryApplicationException catch (error) {
      state = AsyncData<StoriesState>(
        creatingState.copyWith(
          isCreating: false,
          createFailure: error.failure,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<StoriesState>(
        creatingState.copyWith(isCreating: false),
      );
      state = AsyncError<StoriesState>(error, stackTrace);
      return null;
    }

    try {
      final stories = await ref.read(storyRepositoryProvider).getStories();
      state = AsyncData<StoriesState>(StoriesState(stories: stories));
    } on StoryApplicationException catch (error) {
      state = AsyncData<StoriesState>(
        creatingState.copyWith(
          isCreating: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<StoriesState>(
        creatingState.copyWith(isCreating: false),
      );
      state = AsyncError<StoriesState>(error, stackTrace);
    }

    return createdStory;
  }

  void applyUpdatedStory(UserStory updatedStory) {
    final currentState = _currentState;
    if (currentState == null || currentState.hasLoadFailure) {
      return;
    }

    final index = currentState.stories.indexWhere(
      (userStory) => userStory.story.id == updatedStory.story.id,
    );
    if (index < 0) {
      return;
    }

    final stories = List<UserStory>.of(currentState.stories);
    stories[index] = updatedStory;
    state = AsyncData<StoriesState>(
      currentState.copyWith(stories: stories),
    );
  }

  Future<StoriesState> _load(StoryRepository repository) async {
    try {
      final stories = await repository.getStories();
      return StoriesState(stories: stories);
    } on StoryApplicationException catch (error) {
      return StoriesState(loadFailure: error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<StoriesState>;

  StoriesState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StoriesState>) {
      return currentState.value;
    }

    return null;
  }
}
