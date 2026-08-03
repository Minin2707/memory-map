import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/accept_invite_notifier.dart';
import 'package:memory_map/features/invite/application/accept_invite_state.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('AcceptInviteNotifier startup', () {
    test('shouldStartIdleWithoutRepositoryCall', () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(acceptInviteProvider.future);

      expect(state, const AcceptInviteState());
      expect(repository.createCalls, 0);
      expect(repository.acceptCalls, 0);
    });
  });

  group('AcceptInviteNotifier acceptInvite', () {
    test('shouldCreateInputReturnExactUserStoryAndStoreState', () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(acceptInviteProvider.future);

      final result = await container
          .read(acceptInviteProvider.notifier)
          .acceptInvite(' raw-token ');

      expect(result, userStoryFixture);
      expect(repository.acceptCalls, 1);
      expect(repository.createCalls, 0);
      expect(
        repository.receivedAcceptInput,
        AcceptInviteInput(rawToken: ' raw-token '),
      );
      expect(readState(container).isAccepting, isFalse);
      expect(readState(container).acceptedStory, userStoryFixture);
      expect(readState(container).failure, isNull);
    });

    test('shouldExposeAcceptingWhileRepositoryCallIsPending', () async {
      final completer = Completer<UserStory>();
      final repository = FakeInviteRepository()
        ..acceptCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(acceptInviteProvider.future);

      final accept = container
          .read(acceptInviteProvider.notifier)
          .acceptInvite('raw-token');
      await pumpEventQueue();

      expect(readState(container).isAccepting, isTrue);
      expect(readState(container).acceptedStory, isNull);
      expect(readState(container).failure, isNull);

      completer.complete(userStoryFixture);
      await accept;
      expect(readState(container).isAccepting, isFalse);
    });

    test('shouldIgnoreDuplicateAcceptWhileAccepting', () async {
      final completer = Completer<UserStory>();
      final repository = FakeInviteRepository()
        ..acceptCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(acceptInviteProvider.future);
      final notifier = container.read(acceptInviteProvider.notifier);

      final firstAccept = notifier.acceptInvite('raw-token');
      await pumpEventQueue();
      final secondResult = await notifier.acceptInvite('raw-token');

      expect(secondResult, isNull);
      expect(repository.acceptCalls, 1);
      expect(readState(container).isAccepting, isTrue);

      completer.complete(userStoryFixture);
      await firstAccept;
    });

    test('shouldConvertBlankRawTokenToValidationFailureWithoutNewRepositoryCall',
        () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(acceptInviteProvider.future);
      final notifier = container.read(acceptInviteProvider.notifier);
      await notifier.acceptInvite('raw-token');

      final result = await notifier.acceptInvite('   ');

      expect(result, isNull);
      expect(repository.acceptCalls, 1);
      expect(readState(container).isAccepting, isFalse);
      expect(readState(container).acceptedStory, isNull);
      expect(readState(container).failure, const InviteValidationFailure());
    });

    test('shouldExposeKnownFailuresAsTypedFailureAndClearResult', () async {
      final failures = <InviteFailure>[
        const InviteValidationFailure(),
        const InviteUnauthorized(),
        const InviteNotFound(),
        const InviteNetworkUnavailable(),
        const InviteRequestTimedOut(),
        const InviteServerFailure(),
        const UnknownInviteFailure(),
      ];

      for (final failure in failures) {
        final repository = FakeInviteRepository()
          ..acceptResult = userStoryFixture;
        final container = createContainer(repository);
        addTearDown(container.dispose);
        await container.read(acceptInviteProvider.future);
        final notifier = container.read(acceptInviteProvider.notifier);
        await notifier.acceptInvite('raw-token');

        repository.acceptFailure = InviteApplicationException(failure);
        final result = await notifier.acceptInvite('raw-token-2');

        expect(result, isNull);
        expect(readState(container).isAccepting, isFalse);
        expect(readState(container).acceptedStory, isNull);
        expect(readState(container).failure, failure);
      }
    });

    test('shouldExposeUnexpectedFailureAsAsyncErrorAndResetAccepting', () async {
      final repository = FakeInviteRepository()
        ..acceptFailure = const UnexpectedInviteException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(acceptInviteProvider.future);

      final result = await container
          .read(acceptInviteProvider.notifier)
          .acceptInvite('raw-token');

      final value = container.read(acceptInviteProvider);
      expect(result, isNull);
      expect(value, isA<AsyncError<AcceptInviteState>>());
      expect(value.error, isA<UnexpectedInviteException>());
    });

    test('shouldClearOldResultAndFailureBeforeNewRequest', () async {
      final completer = Completer<UserStory>();
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(acceptInviteProvider.future);
      final notifier = container.read(acceptInviteProvider.notifier);
      await notifier.acceptInvite('raw-token');

      repository.acceptCompleter = completer;
      final accept = notifier.acceptInvite('raw-token-2');
      await pumpEventQueue();

      expect(readState(container).acceptedStory, isNull);
      expect(readState(container).failure, isNull);
      expect(readState(container).isAccepting, isTrue);

      completer.complete(secondUserStoryFixture);
      await accept;
      expect(readState(container).acceptedStory, secondUserStoryFixture);
    });

    test('shouldResetToIdle', () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(acceptInviteProvider.future);
      final notifier = container.read(acceptInviteProvider.notifier);
      await notifier.acceptInvite('raw-token');

      notifier.reset();

      expect(readState(container), const AcceptInviteState());
    });
  });
}

ProviderContainer createContainer(FakeInviteRepository repository) {
  final container = ProviderContainer(
    overrides: [
      inviteRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.listen(
    acceptInviteProvider,
    (_, __) {},
    fireImmediately: true,
  );
  return container;
}

AcceptInviteState readState(ProviderContainer container) {
  return container.read(acceptInviteProvider).asData!.value;
}

final Invite inviteFixture = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-123'),
  expiresAt: DateTime.utc(2026, 2, 9, 10),
);

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

final UserStory secondUserStoryFixture = UserStory(
  story: Story(
    id: 'story-id-2',
    title: 'Second Story',
    description: 'Newly accepted',
    createdAt: DateTime.utc(2026, 1, 2, 10),
    updatedAt: DateTime.utc(2026, 1, 11, 10),
  ),
  role: StoryRole.viewer,
);

final class FakeInviteRepository implements InviteRepository {
  int createCalls = 0;
  int acceptCalls = 0;
  CreateInviteInput? receivedCreateInput;
  AcceptInviteInput? receivedAcceptInput;
  Invite createResult = inviteFixture;
  UserStory acceptResult = userStoryFixture;
  Object? createFailure;
  Object? acceptFailure;
  Completer<UserStory>? acceptCompleter;

  @override
  Future<Invite> createInvite(CreateInviteInput input) async {
    createCalls += 1;
    receivedCreateInput = input;

    final failure = createFailure;
    if (failure != null) {
      throw failure;
    }

    return createResult;
  }

  @override
  Future<UserStory> acceptInvite(AcceptInviteInput input) async {
    acceptCalls += 1;
    receivedAcceptInput = input;

    final completer = acceptCompleter;
    if (completer != null) {
      acceptCompleter = null;
      return completer.future;
    }

    final failure = acceptFailure;
    if (failure != null) {
      throw failure;
    }

    return acceptResult;
  }
}

final class UnexpectedInviteException implements Exception {
  const UnexpectedInviteException();
}
