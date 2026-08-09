import 'package:memory_map/features/participant/domain/story_participant.dart';

abstract interface class ParticipantRemoteDataSource {
  Future<List<StoryParticipant>> getParticipants(String storyId);

  Future<void> leaveStory(String storyId);

  Future<void> removeParticipant(
    String storyId,
    String participantUserId,
  );
}
