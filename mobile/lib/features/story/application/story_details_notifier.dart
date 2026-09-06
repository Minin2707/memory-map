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
  int _refreshRevision = 0;

  @override
  Future<StoryDetailsState> build() async {
    _invalidateRefresh();
    return _load(_storyId, ref.watch(storyRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<StoryDetailsState>();
    final retryRevision = ++_refreshRevision;
    final result = await AsyncValue.guard<StoryDetailsState>(() async {
      return _load(_storyId, ref.read(storyRepositoryProvider));
    });
    if (!_isCurrentRefresh(retryRevision)) {
      return;
    }

    state = result;
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
    final refreshRevision = ++_refreshRevision;

    try {
      final userStory = await ref.read(storyRepositoryProvider).getStory(
            _storyId,
          );
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<StoryDetailsState>(
        StoryDetailsState.loaded(userStory: userStory),
      );
    } on StoryApplicationException catch (error) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<StoryDetailsState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<StoryDetailsState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<StoryDetailsState>(error, stackTrace);
    }
  }

  void applyUpdatedStory(UserStory updatedStory) {
    applyStoryMetadataMutation(updatedStory);
  }

  void applyStoryMetadataMutation(UserStory updatedStory) {
    final currentState = _currentState;
    final currentStory = currentState?.userStory;
    if (currentState == null ||
        currentStory == null ||
        currentStory.story.id != updatedStory.story.id) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<StoryDetailsState>(
      currentState.copyWith(
        userStory: currentStory.withStoryMutation(updatedStory.story),
        isRefreshing: false,
        clearRefreshFailure: true,
      ),
    );
  }

  void applyAuthoritativeRead(UserStory userStory) {
    final currentState = _currentState;
    final currentStory = currentState?.userStory;
    if (currentState == null ||
        currentStory == null ||
        currentStory.story.id != userStory.story.id) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<StoryDetailsState>(
      currentState.copyWith(
        userStory: userStory,
        isRefreshing: false,
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

  void _invalidateRefresh() {
    _refreshRevision += 1;
  }

  bool _isCurrentRefresh(int refreshRevision) {
    return ref.mounted && _refreshRevision == refreshRevision;
  }

  StoryDetailsState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StoryDetailsState>) {
      return currentState.value;
    }

    return null;
  }
}
