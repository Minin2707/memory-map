import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_data_source.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_exception.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';

final class DefaultStoryParticipantRepository
    implements StoryParticipantRepository {
  const DefaultStoryParticipantRepository({
    required ParticipantRemoteDataSource participantRemoteDataSource,
  }) : _participantRemoteDataSource = participantRemoteDataSource;

  final ParticipantRemoteDataSource _participantRemoteDataSource;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    try {
      return await _participantRemoteDataSource.getParticipants(storyId);
    } on ParticipantRemoteException catch (exception) {
      throw ParticipantApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<void> leaveStory(LeaveStoryInput input) async {
    try {
      await _participantRemoteDataSource.leaveStory(input.storyId);
    } on ParticipantRemoteException catch (exception) {
      throw ParticipantApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<void> removeParticipant(
    RemoveStoryParticipantInput input,
  ) async {
    try {
      await _participantRemoteDataSource.removeParticipant(
        input.storyId,
        input.participantUserId,
      );
    } on ParticipantRemoteException catch (exception) {
      throw ParticipantApplicationException(_mapFailure(exception));
    }
  }

  ParticipantFailure _mapFailure(ParticipantRemoteException exception) {
    return switch (exception) {
      ParticipantRemoteValidationException() =>
        const ParticipantValidationFailure(),
      ParticipantRemoteUnauthorizedException() =>
        const ParticipantUnauthorized(),
      ParticipantRemoteNotFoundException() => const ParticipantNotFound(),
      ParticipantRemoteLastOwnerConflictException() =>
        const ParticipantLastOwnerConflict(),
      ParticipantRemoteCannotRemoveSelfException() =>
        const ParticipantCannotRemoveSelf(),
      ParticipantRemoteOwnerCannotBeRemovedException() =>
        const ParticipantOwnerCannotBeRemoved(),
      ParticipantRemoteNetworkException() =>
        const ParticipantNetworkUnavailable(),
      ParticipantRemoteTimeoutException() => const ParticipantRequestTimedOut(),
      ParticipantRemoteServerException() => const ParticipantServerFailure(),
      ParticipantRemoteMalformedResponseException() =>
        const UnknownParticipantFailure(),
      ParticipantRemoteUnknownException() => const UnknownParticipantFailure(),
    };
  }
}
