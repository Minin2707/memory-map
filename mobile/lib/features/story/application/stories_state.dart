import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class StoriesState {
  factory StoriesState({
    List<UserStory> stories = const <UserStory>[],
    bool isRefreshing = false,
    bool isCreating = false,
    StoryFailure? loadFailure,
    StoryFailure? refreshFailure,
    StoryFailure? createFailure,
  }) {
    return StoriesState._(
      stories: List<UserStory>.unmodifiable(stories),
      isRefreshing: isRefreshing,
      isCreating: isCreating,
      loadFailure: loadFailure,
      refreshFailure: refreshFailure,
      createFailure: createFailure,
    );
  }

  const StoriesState._({
    required this.stories,
    required this.isRefreshing,
    required this.isCreating,
    required this.loadFailure,
    required this.refreshFailure,
    required this.createFailure,
  });

  final List<UserStory> stories;
  final bool isRefreshing;
  final bool isCreating;
  final StoryFailure? loadFailure;
  final StoryFailure? refreshFailure;
  final StoryFailure? createFailure;

  bool get hasLoadFailure => loadFailure != null;

  bool get isLoaded => loadFailure == null;

  StoriesState copyWith({
    List<UserStory>? stories,
    bool? isRefreshing,
    bool? isCreating,
    StoryFailure? loadFailure,
    StoryFailure? refreshFailure,
    StoryFailure? createFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
    bool clearCreateFailure = false,
  }) {
    return StoriesState(
      stories: stories ?? this.stories,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCreating: isCreating ?? this.isCreating,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
      createFailure:
          clearCreateFailure ? null : createFailure ?? this.createFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoriesState &&
            _listEquals(stories, other.stories) &&
            isRefreshing == other.isRefreshing &&
            isCreating == other.isCreating &&
            loadFailure == other.loadFailure &&
            refreshFailure == other.refreshFailure &&
            createFailure == other.createFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(stories),
        isRefreshing,
        isCreating,
        loadFailure,
        refreshFailure,
        createFailure,
      );

  @override
  String toString() {
    return 'StoriesState(storiesCount: ${stories.length}, '
        'isRefreshing: $isRefreshing, isCreating: $isCreating, '
        'loadFailure: $loadFailure, refreshFailure: $refreshFailure, '
        'createFailure: $createFailure)';
  }

  static bool _listEquals<T>(List<T> left, List<T> right) {
    if (identical(left, right)) {
      return true;
    }

    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
