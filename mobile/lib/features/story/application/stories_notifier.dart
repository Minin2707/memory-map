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
  int _refreshRevision = 0;

  @override
  Future<StoriesState> build() async {
    _invalidateRefresh();
    return _load(ref.watch(storyRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<StoriesState>();
    final retryRevision = ++_refreshRevision;
    final result = await AsyncValue.guard<StoriesState>(() async {
      return _load(ref.read(storyRepositoryProvider));
    });
    if (!_isCurrentRefresh(retryRevision)) {
      return;
    }

    state = result;
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
    final refreshRevision = ++_refreshRevision;

    try {
      final stories = await ref.read(storyRepositoryProvider).getStories();
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<StoriesState>(StoriesState(stories: stories));
    } on StoryApplicationException catch (error) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<StoriesState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

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
      if (!ref.mounted) {
        return createdStory;
      }
    } on StoryApplicationException catch (error) {
      if (!ref.mounted) {
        return null;
      }

      final failedState = _currentState ?? creatingState;
      state = AsyncData<StoriesState>(
        failedState.copyWith(
          isCreating: false,
          createFailure: error.failure,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) {
        return null;
      }

      final failedState = _currentState ?? creatingState;
      state = AsyncData<StoriesState>(
        failedState.copyWith(isCreating: false),
      );
      state = AsyncError<StoriesState>(error, stackTrace);
      return null;
    }

    try {
      final userStory = await ref.read(storyRepositoryProvider).getStory(
            createdStory.id,
          );
      if (!ref.mounted) {
        return createdStory;
      }

      final currentCreateState = _currentState ?? creatingState;
      final stories = _upsertStories(currentCreateState.stories, userStory);
      state = AsyncData<StoriesState>(
        currentCreateState.copyWith(
          stories: stories,
          isCreating: false,
          clearCreateFailure: true,
        ),
      );
    } on StoryApplicationException catch (error) {
      if (!ref.mounted) {
        return createdStory;
      }

      final failedState = _currentState ?? creatingState;
      state = AsyncData<StoriesState>(
        failedState.copyWith(
          isCreating: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) {
        return createdStory;
      }

      final failedState = _currentState ?? creatingState;
      state = AsyncData<StoriesState>(
        failedState.copyWith(isCreating: false),
      );
      state = AsyncError<StoriesState>(error, stackTrace);
    }

    return createdStory;
  }

  void applyUpdatedStory(UserStory updatedStory) {
    applyStoryMetadataMutation(updatedStory);
  }

  void applyStoryMetadataMutation(UserStory updatedStory) {
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
    stories[index] = stories[index].withStoryMutation(updatedStory.story);
    _invalidateRefresh();
    state = AsyncData<StoriesState>(
      currentState.copyWith(stories: stories, isRefreshing: false),
    );
  }

  void applyAuthoritativeRead(UserStory userStory) {
    final currentState = _currentState;
    if (currentState == null || currentState.hasLoadFailure) {
      return;
    }

    final index = currentState.stories.indexWhere(
      (existing) => existing.story.id == userStory.story.id,
    );
    if (index < 0) {
      return;
    }

    final stories = List<UserStory>.of(currentState.stories);
    stories[index] = userStory;
    _invalidateRefresh();
    state = AsyncData<StoriesState>(
      currentState.copyWith(stories: stories, isRefreshing: false),
    );
  }

  void upsertUserStory(UserStory userStory) {
    final currentState = _currentState;
    if (currentState == null || currentState.hasLoadFailure) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<StoriesState>(
      currentState.copyWith(
        stories: _upsertStories(currentState.stories, userStory),
        isRefreshing: false,
      ),
    );
  }

  void removeStoryById(String storyId) {
    final currentState = _currentState;
    if (currentState == null || currentState.hasLoadFailure) {
      return;
    }

    final stories = currentState.stories
        .where((userStory) => userStory.story.id != storyId)
        .toList();
    if (stories.length == currentState.stories.length) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<StoriesState>(
      currentState.copyWith(stories: stories, isRefreshing: false),
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

  void _invalidateRefresh() {
    _refreshRevision += 1;
  }

  bool _isCurrentRefresh(int refreshRevision) {
    return ref.mounted && _refreshRevision == refreshRevision;
  }

  List<UserStory> _upsertStories(
    List<UserStory> currentStories,
    UserStory userStory,
  ) {
    final stories = List<UserStory>.of(currentStories);
    final index = stories.indexWhere(
      (existing) => existing.story.id == userStory.story.id,
    );
    if (index < 0) {
      stories.add(userStory);
    } else {
      stories[index] = userStory;
    }

    return List<UserStory>.unmodifiable(stories);
  }

  StoriesState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StoriesState>) {
      return currentState.value;
    }

    return null;
  }
}
