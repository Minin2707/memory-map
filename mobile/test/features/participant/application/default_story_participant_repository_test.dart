import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/application/default_story_participant_repository.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_data_source.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_exception.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('DefaultStoryParticipantRepository getParticipants', () {
    test('shouldForwardExactStoryId', () async {
      final fakes = ParticipantRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.getParticipants(' story-id ');

      expect(fakes.remote.getCalls, 1);
      expect(fakes.remote.leaveCalls, 0);
      expect(fakes.remote.removeCalls, 0);
      expect(fakes.remote.receivedStoryId, ' story-id ');
    });

    test('shouldReturnExactOrderedParticipantList', () async {
      final participants = <StoryParticipant>[
        participantFixture,
        coOwnerParticipantFixture,
      ];
      final fakes = ParticipantRepositoryFakes()
        ..remote.participants = participants;
      final repository = fakes.createRepository();

      final result = await repository.getParticipants('story-id');

      expect(result, same(participants));
      expect(result, <StoryParticipant>[
        participantFixture,
        coOwnerParticipantFixture,
      ]);
    });

    test('shouldReturnEmptyParticipantList', () async {
      final participants = <StoryParticipant>[];
      final fakes = ParticipantRepositoryFakes()
        ..remote.participants = participants;
      final repository = fakes.createRepository();

      final result = await repository.getParticipants('story-id');

      expect(result, same(participants));
      expect(result, isEmpty);
    });

    test('shouldPreserveNullableAvatarAndRolesWithoutSynthesis', () async {
      final participants = <StoryParticipant>[
        participantFixture,
        viewerParticipantFixture,
      ];
      final fakes = ParticipantRepositoryFakes()
        ..remote.participants = participants;
      final repository = fakes.createRepository();

      final result = await repository.getParticipants('story-id');

      expect(result.first.avatarUrl, isNotNull);
      expect(result.last.avatarUrl, isNull);
      expect(result.first.role, StoryRole.owner);
      expect(result.last.role, StoryRole.viewer);
    });

    test('shouldRejectBlankStoryIdBeforeRemoteCall', () async {
      final fakes = ParticipantRepositoryFakes();
      final repository = fakes.createRepository();

      await expectLater(
        repository.getParticipants('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(fakes.remote.getCalls, 0);
    });
  });

  group('DefaultStoryParticipantRepository leaveStory', () {
    test('shouldForwardExactLeaveStoryId', () async {
      final fakes = ParticipantRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.leaveStory(LeaveStoryInput(storyId: ' story-id '));

      expect(fakes.remote.leaveCalls, 1);
      expect(fakes.remote.getCalls, 0);
      expect(fakes.remote.removeCalls, 0);
      expect(fakes.remote.receivedStoryId, ' story-id ');
    });

    test('shouldCompleteLeaveStoryOnRemoteSuccess', () async {
      final fakes = ParticipantRepositoryFakes();
      final repository = fakes.createRepository();

      await expectLater(
        repository.leaveStory(LeaveStoryInput(storyId: 'story-id')),
        completes,
      );
    });
  });

  group('DefaultStoryParticipantRepository removeParticipant', () {
    test('shouldForwardExactRemoveParticipantIds', () async {
      final fakes = ParticipantRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.removeParticipant(
        RemoveStoryParticipantInput(
          storyId: ' story-id ',
          participantUserId: ' participant-user-id ',
        ),
      );

      expect(fakes.remote.removeCalls, 1);
      expect(fakes.remote.getCalls, 0);
      expect(fakes.remote.leaveCalls, 0);
      expect(fakes.remote.receivedStoryId, ' story-id ');
      expect(fakes.remote.receivedParticipantUserId, ' participant-user-id ');
    });

    test('shouldCompleteRemoveParticipantOnRemoteSuccess', () async {
      final fakes = ParticipantRepositoryFakes();
      final repository = fakes.createRepository();

      await expectLater(
        repository.removeParticipant(
          RemoveStoryParticipantInput(
            storyId: 'story-id',
            participantUserId: 'participant-user-id',
          ),
        ),
        completes,
      );
    });
  });

  group('DefaultStoryParticipantRepository failure mapping', () {
    test('shouldMapKnownRemoteFailures', () async {
      final cases = remoteFailureCases();

      for (final failureCase in cases) {
        await expectGetRemoteFailure(
          failureCase.exception,
          failureCase.failure,
        );
      }
    });

    test('shouldMapBusinessConflictsForLeaveAndRemove', () async {
      await expectLeaveRemoteFailure(
        const ParticipantRemoteLastOwnerConflictException(),
        const ParticipantLastOwnerConflict(),
      );
      await expectRemoveRemoteFailure(
        const ParticipantRemoteCannotRemoveSelfException(),
        const ParticipantCannotRemoveSelf(),
      );
      await expectRemoveRemoteFailure(
        const ParticipantRemoteOwnerCannotBeRemovedException(),
        const ParticipantOwnerCannotBeRemoved(),
      );
    });

    test('shouldNotMaskUnexpectedGetException', () async {
      final fakes = ParticipantRepositoryFakes()
        ..remote.failure = const UnexpectedParticipantException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.getParticipants('story-id'),
        throwsA(isA<UnexpectedParticipantException>()),
      );
    });

    test('shouldNotMaskUnexpectedLeaveException', () async {
      final fakes = ParticipantRepositoryFakes()
        ..remote.failure = const UnexpectedParticipantException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.leaveStory(LeaveStoryInput(storyId: 'story-id')),
        throwsA(isA<UnexpectedParticipantException>()),
      );
    });

    test('shouldNotMaskUnexpectedRemoveException', () async {
      final fakes = ParticipantRepositoryFakes()
        ..remote.failure = const UnexpectedParticipantException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.removeParticipant(
          RemoveStoryParticipantInput(
            storyId: 'story-id',
            participantUserId: 'participant-user-id',
          ),
        ),
        throwsA(isA<UnexpectedParticipantException>()),
      );
    });

    test('shouldNotExposeSensitiveDetailsInApplicationException', () async {
      final fakes = ParticipantRepositoryFakes()
        ..remote.failure = const ParticipantRemoteNotFoundException();
      final repository = fakes.createRepository();

      try {
        await repository.removeParticipant(
          RemoveStoryParticipantInput(
            storyId: 'private-story-id',
            participantUserId: 'private-participant-id',
          ),
        );
        fail('Expected participant application exception');
      } on ParticipantApplicationException catch (error) {
        expect(error.toString(), 'ParticipantApplicationException');
        expect(error.toString(), isNot(contains('private-story-id')));
        expect(error.toString(), isNot(contains('private-participant-id')));
        expect(error.toString(), isNot(contains('token')));
        expect(error.toString(), isNot(contains('Dio')));
        expect(error.toString(), isNot(contains('ParticipantRemote')));
        expect(error.toString(), isNot(contains('ProblemDetail')));
        expect(error.toString(), isNot(contains('HTTP')));
        expect(error.toString(), isNot(contains('404')));
      }
    });
  });

  group('DefaultStoryParticipantRepository construction', () {
    test('shouldNotCallRemoteDuringConstruction', () {
      final fakes = ParticipantRepositoryFakes();

      fakes.createRepository();

      expect(fakes.remote.getCalls, 0);
      expect(fakes.remote.leaveCalls, 0);
      expect(fakes.remote.removeCalls, 0);
    });
  });
}

Future<void> expectGetRemoteFailure(
  ParticipantRemoteException exception,
  ParticipantFailure failure,
) async {
  final fakes = ParticipantRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(
    repository.getParticipants('story-id'),
    failure,
  );
}

Future<void> expectLeaveRemoteFailure(
  ParticipantRemoteException exception,
  ParticipantFailure failure,
) async {
  final fakes = ParticipantRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(
    repository.leaveStory(LeaveStoryInput(storyId: 'story-id')),
    failure,
  );
}

Future<void> expectRemoveRemoteFailure(
  ParticipantRemoteException exception,
  ParticipantFailure failure,
) async {
  final fakes = ParticipantRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(
    repository.removeParticipant(
      RemoveStoryParticipantInput(
        storyId: 'story-id',
        participantUserId: 'participant-user-id',
      ),
    ),
    failure,
  );
}

Future<void> expectApplicationFailure(
  Future<Object?> future,
  ParticipantFailure failure,
) async {
  await expectLater(
    future,
    throwsA(
      isA<ParticipantApplicationException>().having(
        (exception) => exception.failure,
        'failure',
        failure,
      ),
    ),
  );
}

List<RemoteFailureCase> remoteFailureCases() {
  return const <RemoteFailureCase>[
    RemoteFailureCase(
      ParticipantRemoteValidationException(),
      ParticipantValidationFailure(),
    ),
    RemoteFailureCase(
      ParticipantRemoteUnauthorizedException(),
      ParticipantUnauthorized(),
    ),
    RemoteFailureCase(
      ParticipantRemoteNotFoundException(),
      ParticipantNotFound(),
    ),
    RemoteFailureCase(
      ParticipantRemoteLastOwnerConflictException(),
      ParticipantLastOwnerConflict(),
    ),
    RemoteFailureCase(
      ParticipantRemoteCannotRemoveSelfException(),
      ParticipantCannotRemoveSelf(),
    ),
    RemoteFailureCase(
      ParticipantRemoteOwnerCannotBeRemovedException(),
      ParticipantOwnerCannotBeRemoved(),
    ),
    RemoteFailureCase(
      ParticipantRemoteNetworkException(),
      ParticipantNetworkUnavailable(),
    ),
    RemoteFailureCase(
      ParticipantRemoteTimeoutException(),
      ParticipantRequestTimedOut(),
    ),
    RemoteFailureCase(
      ParticipantRemoteServerException(),
      ParticipantServerFailure(),
    ),
    RemoteFailureCase(
      ParticipantRemoteMalformedResponseException(),
      UnknownParticipantFailure(),
    ),
    RemoteFailureCase(
      ParticipantRemoteUnknownException(),
      UnknownParticipantFailure(),
    ),
  ];
}

final StoryParticipant participantFixture = StoryParticipant(
  userId: 'owner-user-id',
  displayName: 'Anna',
  avatarUrl: 'https://cdn.memorymap.app/avatar.png',
  role: StoryRole.owner,
  joinedAt: DateTime.utc(2026, 8, 9, 10),
);

final StoryParticipant coOwnerParticipantFixture = StoryParticipant(
  userId: 'co-owner-user-id',
  displayName: 'Alex',
  avatarUrl: 'https://cdn.memorymap.app/alex.png',
  role: StoryRole.coOwner,
  joinedAt: DateTime.utc(2026, 8, 9, 11),
);

final StoryParticipant viewerParticipantFixture = StoryParticipant(
  userId: 'viewer-user-id',
  displayName: 'Mira',
  avatarUrl: null,
  role: StoryRole.viewer,
  joinedAt: DateTime.utc(2026, 8, 9, 12),
);

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

final class ParticipantRepositoryFakes {
  late final FakeParticipantRemoteDataSource remote =
      FakeParticipantRemoteDataSource();

  DefaultStoryParticipantRepository createRepository() {
    return DefaultStoryParticipantRepository(
      participantRemoteDataSource: remote,
    );
  }
}

final class FakeParticipantRemoteDataSource
    implements ParticipantRemoteDataSource {
  int getCalls = 0;
  int leaveCalls = 0;
  int removeCalls = 0;
  Object? failure;
  String? receivedStoryId;
  String? receivedParticipantUserId;
  List<StoryParticipant> participants = <StoryParticipant>[
    participantFixture,
  ];

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    getCalls += 1;
    receivedStoryId = storyId;
    _throwIfConfigured();

    return participants;
  }

  @override
  Future<void> leaveStory(String storyId) async {
    leaveCalls += 1;
    receivedStoryId = storyId;
    _throwIfConfigured();
  }

  @override
  Future<void> removeParticipant(
    String storyId,
    String participantUserId,
  ) async {
    removeCalls += 1;
    receivedStoryId = storyId;
    receivedParticipantUserId = participantUserId;
    _throwIfConfigured();
  }

  void _throwIfConfigured() {
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }
}

final class RemoteFailureCase {
  const RemoteFailureCase(this.exception, this.failure);

  final ParticipantRemoteException exception;
  final ParticipantFailure failure;
}

final class UnexpectedParticipantException implements Exception {
  const UnexpectedParticipantException();
}
