import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('StoryDetailsState', () {
    test('shouldRepresentLoadedStory', () {
      final state = StoryDetailsState.loaded(userStory: ownerStory);

      expect(state.userStory, ownerStory);
      expect(state.isLoaded, isTrue);
      expect(state.hasLoadFailure, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.loadFailure, isNull);
      expect(state.refreshFailure, isNull);
    });

    test('shouldRepresentInitialLoadFailure', () {
      final state = StoryDetailsState.loadFailure(const StoryNotFound());

      expect(state.userStory, isNull);
      expect(state.isLoaded, isFalse);
      expect(state.hasLoadFailure, isTrue);
      expect(state.loadFailure, const StoryNotFound());
    });

    test('shouldRepresentRefreshingAndRefreshFailure', () {
      final state = StoryDetailsState.loaded(
        userStory: ownerStory,
        isRefreshing: true,
        refreshFailure: const StoryRequestTimedOut(),
      );

      expect(state.isRefreshing, isTrue);
      expect(state.refreshFailure, const StoryRequestTimedOut());
      expect(state.isLoaded, isTrue);
    });

    test('shouldCopyWithUpdatedValuesAndClearFailures', () {
      final initial = StoryDetailsState.loaded(
        userStory: ownerStory,
        isRefreshing: true,
        refreshFailure: const StoryNetworkUnavailable(),
      );

      final copied = initial.copyWith(
        userStory: coOwnerStory,
        isRefreshing: false,
        clearRefreshFailure: true,
      );

      expect(copied.userStory, coOwnerStory);
      expect(copied.isRefreshing, isFalse);
      expect(copied.refreshFailure, isNull);
    });

    test('shouldUseValueSemantics', () {
      final left = StoryDetailsState.loaded(
        userStory: ownerStory,
        refreshFailure: const StoryRequestTimedOut(),
      );
      final right = StoryDetailsState.loaded(
        userStory: ownerStory,
        refreshFailure: const StoryRequestTimedOut(),
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('shouldNotExposeStoryDetailsThroughToString', () {
      final state = StoryDetailsState.loaded(
        userStory: userStory(
          id: 'private-story-id',
          title: 'Private title',
          description: 'Private description',
        ),
        refreshFailure: const StoryNetworkUnavailable(),
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

final UserStory ownerStory = userStory();
final UserStory coOwnerStory = userStory(
  id: 'story-2',
  title: 'Second story',
  role: StoryRole.coOwner,
);
