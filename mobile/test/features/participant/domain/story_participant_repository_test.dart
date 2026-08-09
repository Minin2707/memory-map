import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('StoryParticipantRepository', () {
    test('shouldExposeGetParticipantsContract', () async {
      final repository = FakeStoryParticipantRepository();

      final participants = await repository.getParticipants('story-id');

      expect(repository.receivedGetParticipantsStoryId, 'story-id');
      expect(participants, [createParticipant()]);
    });

    test('shouldExposeLeaveStoryContract', () async {
      final repository = FakeStoryParticipantRepository();
      final input = LeaveStoryInput(storyId: 'story-id');

      await repository.leaveStory(input);

      expect(repository.receivedLeaveStoryInput, input);
    });

    test('shouldExposeRemoveParticipantContract', () async {
      final repository = FakeStoryParticipantRepository();
      final input = RemoveStoryParticipantInput(
        storyId: 'story-id',
        participantUserId: 'participant-user-id',
      );

      await repository.removeParticipant(input);

      expect(repository.receivedRemoveParticipantInput, input);
    });
  });
}

final class FakeStoryParticipantRepository
    implements StoryParticipantRepository {
  String? receivedGetParticipantsStoryId;
  LeaveStoryInput? receivedLeaveStoryInput;
  RemoveStoryParticipantInput? receivedRemoveParticipantInput;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    receivedGetParticipantsStoryId = storyId;

    return [createParticipant()];
  }

  @override
  Future<void> leaveStory(LeaveStoryInput input) async {
    receivedLeaveStoryInput = input;
  }

  @override
  Future<void> removeParticipant(
    RemoveStoryParticipantInput input,
  ) async {
    receivedRemoveParticipantInput = input;
  }
}

StoryParticipant createParticipant() {
  return StoryParticipant(
    userId: 'participant-user-id',
    displayName: 'Anna',
    avatarUrl: null,
    role: StoryRole.viewer,
    joinedAt: DateTime.utc(2026, 8, 3, 10),
  );
}
