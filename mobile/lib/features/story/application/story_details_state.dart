import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class StoryDetailsState {
  factory StoryDetailsState.loaded({
    required UserStory userStory,
    bool isRefreshing = false,
    StoryFailure? refreshFailure,
  }) {
    return StoryDetailsState._(
      userStory: userStory,
      isRefreshing: isRefreshing,
      loadFailure: null,
      refreshFailure: refreshFailure,
    );
  }

  factory StoryDetailsState.loadFailure(StoryFailure failure) {
    return StoryDetailsState._(
      userStory: null,
      isRefreshing: false,
      loadFailure: failure,
      refreshFailure: null,
    );
  }

  const StoryDetailsState._({
    required this.userStory,
    required this.isRefreshing,
    required this.loadFailure,
    required this.refreshFailure,
  });

  final UserStory? userStory;
  final bool isRefreshing;
  final StoryFailure? loadFailure;
  final StoryFailure? refreshFailure;

  bool get isLoaded => userStory != null && loadFailure == null;

  bool get hasLoadFailure => loadFailure != null;

  StoryDetailsState copyWith({
    UserStory? userStory,
    bool? isRefreshing,
    StoryFailure? loadFailure,
    StoryFailure? refreshFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return StoryDetailsState._(
      userStory: userStory ?? this.userStory,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryDetailsState &&
            userStory == other.userStory &&
            isRefreshing == other.isRefreshing &&
            loadFailure == other.loadFailure &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        userStory,
        isRefreshing,
        loadFailure,
        refreshFailure,
      );

  @override
  String toString() {
    return 'StoryDetailsState(hasStory: ${userStory != null}, '
        'isRefreshing: $isRefreshing, loadFailure: $loadFailure, '
        'refreshFailure: $refreshFailure)';
  }
}
