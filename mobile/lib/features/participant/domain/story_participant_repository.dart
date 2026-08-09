import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';

abstract interface class StoryParticipantRepository {
  Future<List<StoryParticipant>> getParticipants(String storyId);

  Future<void> leaveStory(LeaveStoryInput input);

  Future<void> removeParticipant(RemoveStoryParticipantInput input);
}
