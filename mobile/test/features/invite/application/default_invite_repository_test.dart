import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/default_invite_repository.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_data_source.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_exception.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('DefaultInviteRepository createInvite', () {
    test('shouldForwardExactStoryId', () async {
      final fakes = InviteRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.createInvite(CreateInviteInput(storyId: ' story-id '));

      expect(fakes.remote.createCalls, 1);
      expect(fakes.remote.acceptCalls, 0);
      expect(fakes.remote.receivedStoryId, ' story-id ');
    });

    test('shouldReturnExactInviteWithoutModification', () async {
      final fakes = InviteRepositoryFakes();
      final repository = fakes.createRepository();

      final invite = await repository.createInvite(
        CreateInviteInput(storyId: 'story-id'),
      );

      expect(invite, inviteFixture);
      expect(invite.inviteLink, inviteFixture.inviteLink);
      expect(invite.expiresAt, inviteFixture.expiresAt);
    });
  });

  group('DefaultInviteRepository acceptInvite', () {
    test('shouldForwardExactRawToken', () async {
      final fakes = InviteRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.acceptInvite(
        AcceptInviteInput(rawToken: ' raw-token '),
      );

      expect(fakes.remote.acceptCalls, 1);
      expect(fakes.remote.createCalls, 0);
      expect(fakes.remote.receivedRawToken, ' raw-token ');
    });

    test('shouldReturnExactUserStoryWithoutSynthesizingRole', () async {
      final fakes = InviteRepositoryFakes()
        ..remote.userStory = viewerUserStoryFixture;
      final repository = fakes.createRepository();

      final userStory = await repository.acceptInvite(
        AcceptInviteInput(rawToken: 'raw-token'),
      );

      expect(userStory, viewerUserStoryFixture);
      expect(userStory.role, StoryRole.viewer);
    });
  });

  group('DefaultInviteRepository failure mapping', () {
    test('shouldMapKnownRemoteFailuresForCreateInvite', () async {
      final cases = remoteFailureCases();

      for (final failureCase in cases) {
        await expectCreateRemoteFailure(
          failureCase.exception,
          failureCase.failure,
        );
      }
    });

    test('shouldMapKnownRemoteFailuresForAcceptInvite', () async {
      final cases = remoteFailureCases();

      for (final failureCase in cases) {
        await expectAcceptRemoteFailure(
          failureCase.exception,
          failureCase.failure,
        );
      }
    });

    test('shouldNotMaskUnexpectedCreateException', () async {
      final fakes = InviteRepositoryFakes()
        ..remote.failure = const UnexpectedInviteException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.createInvite(CreateInviteInput(storyId: 'story-id')),
        throwsA(isA<UnexpectedInviteException>()),
      );
    });

    test('shouldNotMaskUnexpectedAcceptException', () async {
      final fakes = InviteRepositoryFakes()
        ..remote.failure = const UnexpectedInviteException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.acceptInvite(AcceptInviteInput(rawToken: 'raw-token')),
        throwsA(isA<UnexpectedInviteException>()),
      );
    });

    test('shouldNotExposeSensitiveDetailsInApplicationException', () async {
      final fakes = InviteRepositoryFakes()
        ..remote.failure = const InviteRemoteNotFoundException();
      final repository = fakes.createRepository();

      try {
        await repository.acceptInvite(
          AcceptInviteInput(rawToken: 'private-token'),
        );
        fail('Expected invite application exception');
      } on InviteApplicationException catch (error) {
        expect(error.toString(), 'InviteApplicationException');
        expect(error.toString(), isNot(contains('private-token')));
        expect(error.toString(), isNot(contains('share-token-123')));
        expect(error.toString(), isNot(contains('story-id')));
        expect(error.toString(), isNot(contains('Dio')));
        expect(error.toString(), isNot(contains('InviteRemote')));
        expect(error.toString(), isNot(contains('HTTP')));
        expect(error.toString(), isNot(contains('404')));
      }
    });
  });

  group('DefaultInviteRepository construction', () {
    test('shouldNotCallRemoteDuringConstruction', () {
      final fakes = InviteRepositoryFakes();

      fakes.createRepository();

      expect(fakes.remote.createCalls, 0);
      expect(fakes.remote.acceptCalls, 0);
    });
  });
}

Future<void> expectCreateRemoteFailure(
  InviteRemoteException exception,
  InviteFailure failure,
) async {
  final fakes = InviteRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(
    repository.createInvite(CreateInviteInput(storyId: 'story-id')),
    failure,
  );
}

Future<void> expectAcceptRemoteFailure(
  InviteRemoteException exception,
  InviteFailure failure,
) async {
  final fakes = InviteRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(
    repository.acceptInvite(AcceptInviteInput(rawToken: 'raw-token')),
    failure,
  );
}

Future<void> expectApplicationFailure(
  Future<Object?> future,
  InviteFailure failure,
) async {
  await expectLater(
    future,
    throwsA(
      isA<InviteApplicationException>().having(
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
      InviteRemoteValidationException(),
      InviteValidationFailure(),
    ),
    RemoteFailureCase(
      InviteRemoteUnauthorizedException(),
      InviteUnauthorized(),
    ),
    RemoteFailureCase(
      InviteRemoteNotFoundException(),
      InviteNotFound(),
    ),
    RemoteFailureCase(
      InviteRemoteNetworkException(),
      InviteNetworkUnavailable(),
    ),
    RemoteFailureCase(
      InviteRemoteTimeoutException(),
      InviteRequestTimedOut(),
    ),
    RemoteFailureCase(
      InviteRemoteServerException(),
      InviteServerFailure(),
    ),
    RemoteFailureCase(
      InviteRemoteMalformedResponseException(),
      UnknownInviteFailure(),
    ),
    RemoteFailureCase(
      InviteRemoteUnknownException(),
      UnknownInviteFailure(),
    ),
  ];
}

final Invite inviteFixture = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-123'),
  expiresAt: DateTime.utc(2026, 2, 9, 10),
);

final Story storyFixture = Story(
  id: 'story-id',
  title: 'Our Story',
  description: 'Together since 2021',
  createdAt: DateTime.utc(2026, 1, 1, 10),
  updatedAt: DateTime.utc(2026, 1, 10, 10),
);

final UserStory userStoryFixture = UserStory(
  story: storyFixture,
  role: StoryRole.coOwner,
);

final UserStory viewerUserStoryFixture = UserStory(
  story: storyFixture,
  role: StoryRole.viewer,
);

final class InviteRepositoryFakes {
  late final FakeInviteRemoteDataSource remote = FakeInviteRemoteDataSource();

  DefaultInviteRepository createRepository() {
    return DefaultInviteRepository(inviteRemoteDataSource: remote);
  }
}

final class FakeInviteRemoteDataSource implements InviteRemoteDataSource {
  int createCalls = 0;
  int acceptCalls = 0;
  Object? failure;
  String? receivedStoryId;
  String? receivedRawToken;
  Invite invite = inviteFixture;
  UserStory userStory = userStoryFixture;

  @override
  Future<Invite> createInvite(String storyId) async {
    createCalls += 1;
    receivedStoryId = storyId;
    _throwIfConfigured();

    return invite;
  }

  @override
  Future<UserStory> acceptInvite(String rawToken) async {
    acceptCalls += 1;
    receivedRawToken = rawToken;
    _throwIfConfigured();

    return userStory;
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

  final InviteRemoteException exception;
  final InviteFailure failure;
}

final class UnexpectedInviteException implements Exception {
  const UnexpectedInviteException();
}
