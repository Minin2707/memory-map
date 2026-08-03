import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/create_invite_notifier.dart';
import 'package:memory_map/features/invite/application/create_invite_state.dart';
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
  group('CreateInviteNotifier startup', () {
    test('shouldStartIdleWithoutRepositoryCall', () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(createInviteProvider.future);

      expect(state, const CreateInviteState());
      expect(repository.createCalls, 0);
      expect(repository.acceptCalls, 0);
    });
  });

  group('CreateInviteNotifier createInvite', () {
    test('shouldCreateInputReturnExactInviteAndStoreState', () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createInviteProvider.future);

      final result = await container
          .read(createInviteProvider.notifier)
          .createInvite(' story-id ');

      expect(result, inviteFixture);
      expect(repository.createCalls, 1);
      expect(repository.acceptCalls, 0);
      expect(
        repository.receivedCreateInput,
        CreateInviteInput(storyId: ' story-id '),
      );
      expect(readState(container).isCreating, isFalse);
      expect(readState(container).createdInvite, inviteFixture);
      expect(readState(container).failure, isNull);
    });

    test('shouldExposeCreatingWhileRepositoryCallIsPending', () async {
      final completer = Completer<Invite>();
      final repository = FakeInviteRepository()
        ..createCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createInviteProvider.future);

      final create = container
          .read(createInviteProvider.notifier)
          .createInvite('story-id');
      await pumpEventQueue();

      expect(readState(container).isCreating, isTrue);
      expect(readState(container).createdInvite, isNull);
      expect(readState(container).failure, isNull);

      completer.complete(inviteFixture);
      await create;
      expect(readState(container).isCreating, isFalse);
    });

    test('shouldIgnoreDuplicateCreateWhileCreating', () async {
      final completer = Completer<Invite>();
      final repository = FakeInviteRepository()
        ..createCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createInviteProvider.future);
      final notifier = container.read(createInviteProvider.notifier);

      final firstCreate = notifier.createInvite('story-id');
      await pumpEventQueue();
      final secondResult = await notifier.createInvite('story-id');

      expect(secondResult, isNull);
      expect(repository.createCalls, 1);
      expect(readState(container).isCreating, isTrue);

      completer.complete(inviteFixture);
      await firstCreate;
    });

    test('shouldConvertBlankStoryIdToValidationFailureWithoutNewRepositoryCall',
        () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createInviteProvider.future);
      final notifier = container.read(createInviteProvider.notifier);
      await notifier.createInvite('story-id');

      final result = await notifier.createInvite('   ');

      expect(result, isNull);
      expect(repository.createCalls, 1);
      expect(readState(container).isCreating, isFalse);
      expect(readState(container).createdInvite, isNull);
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
          ..createResult = inviteFixture;
        final container = createContainer(repository);
        addTearDown(container.dispose);
        await container.read(createInviteProvider.future);
        final notifier = container.read(createInviteProvider.notifier);
        await notifier.createInvite('story-id');

        repository.createFailure = InviteApplicationException(failure);
        final result = await notifier.createInvite('story-id-2');

        expect(result, isNull);
        expect(readState(container).isCreating, isFalse);
        expect(readState(container).createdInvite, isNull);
        expect(readState(container).failure, failure);
      }
    });

    test('shouldExposeUnexpectedFailureAsAsyncErrorAndResetCreating', () async {
      final repository = FakeInviteRepository()
        ..createFailure = const UnexpectedInviteException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createInviteProvider.future);

      final result = await container
          .read(createInviteProvider.notifier)
          .createInvite('story-id');

      final value = container.read(createInviteProvider);
      expect(result, isNull);
      expect(value, isA<AsyncError<CreateInviteState>>());
      expect(value.error, isA<UnexpectedInviteException>());
    });

    test('shouldClearOldResultAndFailureBeforeNewRequest', () async {
      final completer = Completer<Invite>();
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createInviteProvider.future);
      final notifier = container.read(createInviteProvider.notifier);
      await notifier.createInvite('story-id');

      repository.createCompleter = completer;
      final create = notifier.createInvite('story-id-2');
      await pumpEventQueue();

      expect(readState(container).createdInvite, isNull);
      expect(readState(container).failure, isNull);
      expect(readState(container).isCreating, isTrue);

      completer.complete(secondInviteFixture);
      await create;
      expect(readState(container).createdInvite, secondInviteFixture);
    });

    test('shouldResetToIdle', () async {
      final repository = FakeInviteRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createInviteProvider.future);
      final notifier = container.read(createInviteProvider.notifier);
      await notifier.createInvite('story-id');

      notifier.reset();

      expect(readState(container), const CreateInviteState());
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
    createInviteProvider,
    (_, __) {},
    fireImmediately: true,
  );
  return container;
}

CreateInviteState readState(ProviderContainer container) {
  return container.read(createInviteProvider).asData!.value;
}

final Invite inviteFixture = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-123'),
  expiresAt: DateTime.utc(2026, 2, 9, 10),
);

final Invite secondInviteFixture = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-456'),
  expiresAt: DateTime.utc(2026, 2, 10, 10),
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

final class FakeInviteRepository implements InviteRepository {
  int createCalls = 0;
  int acceptCalls = 0;
  CreateInviteInput? receivedCreateInput;
  AcceptInviteInput? receivedAcceptInput;
  Invite createResult = inviteFixture;
  UserStory acceptResult = userStoryFixture;
  Object? createFailure;
  Object? acceptFailure;
  Completer<Invite>? createCompleter;

  @override
  Future<Invite> createInvite(CreateInviteInput input) async {
    createCalls += 1;
    receivedCreateInput = input;

    final completer = createCompleter;
    if (completer != null) {
      createCompleter = null;
      return completer.future;
    }

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
