import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';

void main() {
  group('LeaveStoryInput', () {
    test('shouldCreateInput', () {
      final input = LeaveStoryInput(storyId: 'story-id');

      expect(input.storyId, 'story-id');
    });

    test('shouldRejectBlankStoryId', () {
      expect(
        () => LeaveStoryInput(storyId: '   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
    });

    test('shouldNotNormalizeStoryId', () {
      final input = LeaveStoryInput(storyId: ' story-id ');

      expect(input.storyId, ' story-id ');
    });

    test('shouldCompareInputsByValue', () {
      final first = LeaveStoryInput(storyId: 'story-id');
      final second = LeaveStoryInput(storyId: 'story-id');
      final different = LeaveStoryInput(storyId: 'another-story-id');

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final input = LeaveStoryInput(storyId: 'story-id');

      expect(input.toString(), 'LeaveStoryInput');
      expect(input.toString(), isNot(contains('story-id')));
      expect(input.toString(), isNot(contains('user-id')));
      expect(input.toString(), isNot(contains('token')));
    });
  });

  group('RemoveStoryParticipantInput', () {
    test('shouldCreateInput', () {
      final input = RemoveStoryParticipantInput(
        storyId: 'story-id',
        participantUserId: 'participant-user-id',
      );

      expect(input.storyId, 'story-id');
      expect(input.participantUserId, 'participant-user-id');
    });

    test('shouldRejectBlankStoryId', () {
      expect(
        () => RemoveStoryParticipantInput(
          storyId: '   ',
          participantUserId: 'participant-user-id',
        ),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
    });

    test('shouldRejectBlankParticipantUserId', () {
      expect(
        () => RemoveStoryParticipantInput(
          storyId: 'story-id',
          participantUserId: '   ',
        ),
        throwsA(
          argumentErrorWithMessage('participantUserId must not be blank'),
        ),
      );
    });

    test('shouldNotNormalizeIdentifiers', () {
      final input = RemoveStoryParticipantInput(
        storyId: ' story-id ',
        participantUserId: ' participant-user-id ',
      );

      expect(input.storyId, ' story-id ');
      expect(input.participantUserId, ' participant-user-id ');
    });

    test('shouldAllowSelfLikeEqualIdentifiersAtConstruction', () {
      final input = RemoveStoryParticipantInput(
        storyId: 'same-id',
        participantUserId: 'same-id',
      );

      expect(input.storyId, 'same-id');
      expect(input.participantUserId, 'same-id');
    });

    test('shouldCompareInputsByValue', () {
      final first = createRemoveInput();
      final second = createRemoveInput();
      final different = createRemoveInput(
        participantUserId: 'another-user-id',
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final input = createRemoveInput();

      expect(input.toString(), 'RemoveStoryParticipantInput');
      expect(input.toString(), isNot(contains('story-id')));
      expect(input.toString(), isNot(contains('participant-user-id')));
      expect(input.toString(), isNot(contains('actor')));
      expect(input.toString(), isNot(contains('role')));
      expect(input.toString(), isNot(contains('ownerId')));
      expect(input.toString(), isNot(contains('token')));
      expect(input.toString(), isNot(contains('Dio')));
      expect(input.toString(), isNot(contains('HTTP')));
    });
  });
}

RemoveStoryParticipantInput createRemoveInput({
  String storyId = 'story-id',
  String participantUserId = 'participant-user-id',
}) {
  return RemoveStoryParticipantInput(
    storyId: storyId,
    participantUserId: participantUserId,
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
