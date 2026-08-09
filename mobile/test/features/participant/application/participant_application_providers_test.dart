import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/application/default_story_participant_repository.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/data/remote/dio_participant_remote_data_source.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_data_source.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('storyParticipantRepositoryProvider', () {
    test('shouldCreateStoryParticipantRepositoryFromRemoteProvider', () {
      final remote = FakeParticipantRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          participantRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(storyParticipantRepositoryProvider);

      expect(repository, isA<StoryParticipantRepository>());
      expect(repository, isA<DefaultStoryParticipantRepository>());
      expect(remote.totalCalls, 0);
    });

    test('shouldDelegateThroughProviderCreatedRepository', () async {
      final remote = FakeParticipantRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          participantRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(storyParticipantRepositoryProvider);

      final participants = await repository.getParticipants('story-id');
      await repository.leaveStory(LeaveStoryInput(storyId: 'leave-story-id'));
      await repository.removeParticipant(
        RemoveStoryParticipantInput(
          storyId: 'remove-story-id',
          participantUserId: 'participant-user-id',
        ),
      );

      expect(participants, <StoryParticipant>[participantFixture]);
      expect(remote.receivedGetStoryId, 'story-id');
      expect(remote.receivedLeaveStoryId, 'leave-story-id');
      expect(remote.receivedRemoveStoryId, 'remove-story-id');
      expect(remote.receivedParticipantUserId, 'participant-user-id');
      expect(remote.totalCalls, 3);
    });
  });
}

final StoryParticipant participantFixture = StoryParticipant(
  userId: 'user-id',
  displayName: 'Anna',
  avatarUrl: null,
  role: StoryRole.owner,
  joinedAt: DateTime.utc(2026, 8, 9, 10),
);

final class FakeParticipantRemoteDataSource
    implements ParticipantRemoteDataSource {
  int totalCalls = 0;
  String? receivedGetStoryId;
  String? receivedLeaveStoryId;
  String? receivedRemoveStoryId;
  String? receivedParticipantUserId;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    totalCalls += 1;
    receivedGetStoryId = storyId;

    return <StoryParticipant>[participantFixture];
  }

  @override
  Future<void> leaveStory(String storyId) async {
    totalCalls += 1;
    receivedLeaveStoryId = storyId;
  }

  @override
  Future<void> removeParticipant(
    String storyId,
    String participantUserId,
  ) async {
    totalCalls += 1;
    receivedRemoveStoryId = storyId;
    receivedParticipantUserId = participantUserId;
  }
}
