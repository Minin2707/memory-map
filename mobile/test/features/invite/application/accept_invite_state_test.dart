import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/accept_invite_state.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('AcceptInviteState', () {
    test('shouldStartIdleByDefault', () {
      const state = AcceptInviteState();

      expect(state.isAccepting, isFalse);
      expect(state.acceptedStory, isNull);
      expect(state.hasAcceptedStory, isFalse);
      expect(state.failure, isNull);
    });

    test('shouldCopyValues', () {
      final state = const AcceptInviteState().copyWith(
        isAccepting: true,
        acceptedStory: userStoryFixture,
        failure: const InviteServerFailure(),
      );

      expect(state.isAccepting, isTrue);
      expect(state.acceptedStory, userStoryFixture);
      expect(state.hasAcceptedStory, isTrue);
      expect(state.failure, const InviteServerFailure());
    });

    test('shouldClearNullableValues', () {
      final state = AcceptInviteState(
        acceptedStory: userStoryFixture,
        failure: const InviteServerFailure(),
      ).copyWith(
        clearAcceptedStory: true,
        clearFailure: true,
      );

      expect(state.acceptedStory, isNull);
      expect(state.hasAcceptedStory, isFalse);
      expect(state.failure, isNull);
    });

    test('shouldSupportEqualityAndHashCode', () {
      final first = AcceptInviteState(
        isAccepting: true,
        acceptedStory: userStoryFixture,
        failure: const InviteNetworkUnavailable(),
      );
      final second = AcceptInviteState(
        isAccepting: true,
        acceptedStory: userStoryFixture,
        failure: const InviteNetworkUnavailable(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('shouldHaveSafeToString', () {
      final state = AcceptInviteState(acceptedStory: userStoryFixture);

      expect(
        state.toString(),
        'AcceptInviteState(isAccepting: false, hasAcceptedStory: true, '
        'failure: null)',
      );
      expect(state.toString(), isNot(contains('raw-token')));
      expect(state.toString(), isNot(contains('story-id')));
      expect(state.toString(), isNot(contains('Our Story')));
      expect(state.toString(), isNot(contains('Together since 2021')));
      expect(state.toString(), isNot(contains('Dio')));
      expect(state.toString(), isNot(contains('HTTP')));
    });
  });
}

final UserStory userStoryFixture = UserStory(
  story: Story(
    id: 'story-id',
    title: 'Our Story',
    description: 'Together since 2021',
    createdAt: DateTime.utc(2026, 1, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10, 10),
  ),
  role: StoryRole.coOwner,
);
