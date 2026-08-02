import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/stories_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('StoriesState', () {
    test('shouldRepresentLoadedEmptyList', () {
      final state = StoriesState();

      expect(state.stories, isEmpty);
      expect(state.isLoaded, isTrue);
      expect(state.hasLoadFailure, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.isCreating, isFalse);
    });

    test('shouldCopyStoriesIntoUnmodifiableList', () {
      final stories = <UserStory>[userStory()];

      final state = StoriesState(stories: stories);
      stories.add(userStory(id: 'story-2'));

      expect(state.stories, <UserStory>[userStory()]);
      expect(
        () => state.stories.add(userStory(id: 'story-3')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('shouldExposeOperationFailures', () {
      final state = StoriesState(
        loadFailure: const StoryNetworkUnavailable(),
        refreshFailure: const StoryRequestTimedOut(),
        createFailure: const StoryValidationFailure(),
      );

      expect(state.hasLoadFailure, isTrue);
      expect(state.isLoaded, isFalse);
      expect(state.loadFailure, const StoryNetworkUnavailable());
      expect(state.refreshFailure, const StoryRequestTimedOut());
      expect(state.createFailure, const StoryValidationFailure());
    });

    test('shouldCopyWithUpdatedValues', () {
      final initial = StoriesState(
        stories: <UserStory>[userStory()],
        isRefreshing: true,
        isCreating: true,
        loadFailure: const StoryNetworkUnavailable(),
        refreshFailure: const StoryRequestTimedOut(),
        createFailure: const StoryValidationFailure(),
      );
      final replacement = userStory(id: 'story-2');

      final copied = initial.copyWith(
        stories: <UserStory>[replacement],
        isRefreshing: false,
        isCreating: false,
        clearLoadFailure: true,
        clearRefreshFailure: true,
        clearCreateFailure: true,
      );

      expect(copied.stories, <UserStory>[replacement]);
      expect(copied.isRefreshing, isFalse);
      expect(copied.isCreating, isFalse);
      expect(copied.loadFailure, isNull);
      expect(copied.refreshFailure, isNull);
      expect(copied.createFailure, isNull);
    });

    test('shouldUseDeepListEquality', () {
      final left = StoriesState(
        stories: <UserStory>[userStory()],
        refreshFailure: const StoryRequestTimedOut(),
      );
      final right = StoriesState(
        stories: <UserStory>[userStory()],
        refreshFailure: const StoryRequestTimedOut(),
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('shouldNotExposeStoryDetailsThroughToString', () {
      final state = StoriesState(
        stories: <UserStory>[
          userStory(
            id: 'private-story-id',
            title: 'Private title',
            description: 'Private description',
          ),
        ],
        loadFailure: const StoryNotFound(),
      );

      final text = state.toString();

      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('token')));
    });
  });
}

UserStory userStory({
  String id = 'story-1',
  String title = 'First story',
  String? description = 'First description',
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
  );
}
