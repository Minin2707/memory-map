import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/participant/application/participants_state.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('ParticipantsNotifier startup', () {
    test('shouldStartWithAsyncLoading', () async {
      final completer = Completer<List<StoryParticipant>>();
      final repository = FakeStoryParticipantRepository()
        ..getCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final future = container.read(storyParticipantsProvider('story-1').future);

      expect(
        container.read(storyParticipantsProvider('story-1')),
        isA<AsyncLoading<ParticipantsState>>(),
      );

      completer.complete(<StoryParticipant>[ownerParticipant]);
      await future;
    });

    test('shouldLoadParticipantsFromRepository', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[
          ownerParticipant,
          viewerParticipant,
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyParticipantsProvider('story-1').future,
      );

      expect(state.participants, <StoryParticipant>[
        ownerParticipant,
        viewerParticipant,
      ]);
      expect(repository.receivedGetStoryId, 'story-1');
      expect(repository.getCalls, 1);
    });

    test('shouldPreserveBackendOrderAndParticipantFields', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[
          viewerParticipant,
          ownerParticipant,
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyParticipantsProvider('story-1').future,
      );

      expect(state.participants, <StoryParticipant>[
        viewerParticipant,
        ownerParticipant,
      ]);
      expect(state.participants.first.avatarUrl, isNull);
      expect(state.participants.first.role, StoryRole.viewer);
      expect(state.participants.last.role, StoryRole.owner);
    });

    test('shouldRepresentEmptyLoadedListWithoutFailure', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyParticipantsProvider('story-1').future,
      );

      expect(state.participants, isEmpty);
      expect(state.loadFailure, isNull);
    });

    test('shouldExposeKnownLoadFailureAsState', () async {
      final repository = FakeStoryParticipantRepository()
        ..getFailures.add(
          const ParticipantApplicationException(ParticipantUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        storyParticipantsProvider('story-1').future,
      );

      expect(state.participants, isEmpty);
      expect(state.loadFailure, const ParticipantUnauthorized());
    });

    test('shouldExposeUnexpectedLoadFailureAsAsyncError', () async {
      final repository = FakeStoryParticipantRepository()
        ..getFailures.add(const UnexpectedParticipantException());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<ParticipantsState>>();
      final subscription = container.listen(
        storyParticipantsProvider('story-1'),
        (previous, next) {
          if (next.hasError && !errorState.isCompleted) {
            errorState.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final state = await errorState.future;

      expect(state.hasError, isTrue);
      expect(state.error, isA<UnexpectedParticipantException>());
    });

    test('shouldRejectBlankStoryIdWithoutRepositoryCall', () async {
      final repository = FakeStoryParticipantRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storyParticipantsProvider('   ').future);

      expect(state.loadFailure, const ParticipantValidationFailure());
      expect(repository.getCalls, 0);
    });
  });

  group('ParticipantsNotifier retry', () {
    test('shouldRetryAfterKnownLoadFailure', () async {
      final repository = FakeStoryParticipantRepository()
        ..getFailures.add(
          const ParticipantApplicationException(
            ParticipantNetworkUnavailable(),
          ),
        )
        ..participantsResults.add(<StoryParticipant>[ownerParticipant]);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      await container
          .read(storyParticipantsProvider('story-1').notifier)
          .retryLoad();

      expect(repository.getCalls, 2);
      expect(readState(container, 'story-1').participants, <StoryParticipant>[
        ownerParticipant,
      ]);
      expect(readState(container, 'story-1').loadFailure, isNull);
    });

    test('shouldShowLoadingDuringRetryAndIgnoreDuplicateRetry', () async {
      final retryCompleter = Completer<List<StoryParticipant>>();
      final repository = FakeStoryParticipantRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      repository.getCompleter = retryCompleter;

      final notifier = container.read(
        storyParticipantsProvider('story-1').notifier,
      );
      final retry = notifier.retryLoad();
      await pumpEventQueue();
      await notifier.retryLoad();

      expect(
        container.read(storyParticipantsProvider('story-1')),
        isA<AsyncLoading<ParticipantsState>>(),
      );
      expect(repository.getCalls, 2);

      retryCompleter.complete(<StoryParticipant>[ownerParticipant]);
      await retry;
    });
  });

  group('ParticipantsNotifier refresh', () {
    test('shouldPreserveParticipantsWhileRefreshing', () async {
      final refreshCompleter = Completer<List<StoryParticipant>>();
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      repository.getCompleter = refreshCompleter;

      final refresh = container
          .read(storyParticipantsProvider('story-1').notifier)
          .refreshParticipants();
      await pumpEventQueue();

      final state = readState(container, 'story-1');
      expect(state.participants, <StoryParticipant>[ownerParticipant]);
      expect(state.isRefreshing, isTrue);

      refreshCompleter.complete(<StoryParticipant>[viewerParticipant]);
      await refresh;
    });

    test('shouldReplaceParticipantsWithAuthoritativeRefreshResult', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      repository.participantsResult = <StoryParticipant>[
        viewerParticipant,
        ownerParticipant,
      ];

      await container
          .read(storyParticipantsProvider('story-1').notifier)
          .refreshParticipants();

      final state = readState(container, 'story-1');
      expect(state.participants, <StoryParticipant>[
        viewerParticipant,
        ownerParticipant,
      ]);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, isNull);
    });

    test('shouldKeepParticipantsAndExposeRefreshFailureForKnownFailure',
        () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      repository.getFailures.add(
        const ParticipantApplicationException(ParticipantRequestTimedOut()),
      );

      await container
          .read(storyParticipantsProvider('story-1').notifier)
          .refreshParticipants();

      final state = readState(container, 'story-1');
      expect(state.participants, <StoryParticipant>[ownerParticipant]);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, const ParticipantRequestTimedOut());
    });

    test('shouldExposeUnexpectedRefreshFailureAsAsyncError', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      repository.getFailures.add(const UnexpectedParticipantException());

      await container
          .read(storyParticipantsProvider('story-1').notifier)
          .refreshParticipants();

      expect(
        container.read(storyParticipantsProvider('story-1')),
        isA<AsyncError<ParticipantsState>>(),
      );
    });

    test('shouldIgnoreDuplicateRefreshAndRefreshAfterLoadFailure', () async {
      final refreshCompleter = Completer<List<StoryParticipant>>();
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      repository.getCompleter = refreshCompleter;

      final notifier = container.read(
        storyParticipantsProvider('story-1').notifier,
      );
      final firstRefresh = notifier.refreshParticipants();
      await pumpEventQueue();
      await notifier.refreshParticipants();

      expect(repository.getCalls, 2);

      refreshCompleter.complete(<StoryParticipant>[ownerParticipant]);
      await firstRefresh;

      final failedRepository = FakeStoryParticipantRepository()
        ..getFailures.add(
          const ParticipantApplicationException(ParticipantNotFound()),
        );
      final failedContainer = createContainer(failedRepository);
      addTearDown(failedContainer.dispose);
      await failedContainer.read(storyParticipantsProvider('story-2').future);

      await failedContainer
          .read(storyParticipantsProvider('story-2').notifier)
          .refreshParticipants();

      expect(failedRepository.getCalls, 1);
    });
  });

  group('ParticipantsNotifier leaveStory', () {
    test('shouldReturnTrueAndPreserveParticipantsOnLeaveSuccess', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final result = await container
          .read(storyParticipantsProvider('story-1').notifier)
          .leaveStory();

      expect(result, isTrue);
      expect(repository.leaveCalls, 1);
      expect(repository.receivedLeaveInput, LeaveStoryInput(storyId: 'story-1'));
      expect(readState(container, 'story-1').participants, <StoryParticipant>[
        ownerParticipant,
      ]);
      expect(readState(container, 'story-1').isLeaving, isFalse);
      expect(readState(container, 'story-1').leaveFailure, isNull);
    });

    test('shouldExposeLeavingWhileLeaveIsPendingAndIgnoreDuplicate', () async {
      final leaveCompleter = Completer<void>();
      final repository = FakeStoryParticipantRepository()
        ..leaveCompleter = leaveCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      final notifier = container.read(
        storyParticipantsProvider('story-1').notifier,
      );

      final firstLeave = notifier.leaveStory();
      await pumpEventQueue();
      final secondResult = await notifier.leaveStory();

      expect(secondResult, isFalse);
      expect(repository.leaveCalls, 1);
      expect(readState(container, 'story-1').isLeaving, isTrue);

      leaveCompleter.complete();
      expect(await firstLeave, isTrue);
    });

    test('shouldExposeKnownLeaveFailuresAndPreserveParticipants', () async {
      final failures = <ParticipantFailure>[
        const ParticipantLastOwnerConflict(),
        const ParticipantNotFound(),
        const ParticipantUnauthorized(),
        const ParticipantNetworkUnavailable(),
        const ParticipantServerFailure(),
      ];

      for (final failure in failures) {
        final repository = FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[ownerParticipant]
          ..leaveFailure = ParticipantApplicationException(failure);
        final container = createContainer(repository);
        addTearDown(container.dispose);
        await container.read(storyParticipantsProvider('story-1').future);

        final result = await container
            .read(storyParticipantsProvider('story-1').notifier)
            .leaveStory();

        expect(result, isFalse);
        expect(readState(container, 'story-1').participants, <StoryParticipant>[
          ownerParticipant,
        ]);
        expect(readState(container, 'story-1').isLeaving, isFalse);
        expect(readState(container, 'story-1').leaveFailure, failure);
      }
    });

    test('shouldExposeUnexpectedLeaveFailureAsAsyncError', () async {
      final repository = FakeStoryParticipantRepository()
        ..leaveFailure = const UnexpectedParticipantException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final result = await container
          .read(storyParticipantsProvider('story-1').notifier)
          .leaveStory();

      expect(result, isFalse);
      expect(
        container.read(storyParticipantsProvider('story-1')),
        isA<AsyncError<ParticipantsState>>(),
      );
    });
  });

  group('ParticipantsNotifier removeParticipant', () {
    test('shouldRemoveTargetAfterBackendSuccessAndPreserveOrder', () async {
      final source = <StoryParticipant>[
        ownerParticipant,
        viewerParticipant,
        editorParticipant,
      ];
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = source;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final result = await container
          .read(storyParticipantsProvider('story-1').notifier)
          .removeParticipant('viewer-user-id');

      expect(result, isTrue);
      expect(repository.removeCalls, 1);
      expect(
        repository.receivedRemoveInput,
        RemoveStoryParticipantInput(
          storyId: 'story-1',
          participantUserId: 'viewer-user-id',
        ),
      );
      expect(readState(container, 'story-1').participants, <StoryParticipant>[
        ownerParticipant,
        editorParticipant,
      ]);
      expect(source, <StoryParticipant>[
        ownerParticipant,
        viewerParticipant,
        editorParticipant,
      ]);
      expect(readState(container, 'story-1').removingParticipantUserId, isNull);
    });

    test('shouldKeepListWhenMissingLocalTargetSucceeds', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final result = await container
          .read(storyParticipantsProvider('story-1').notifier)
          .removeParticipant('missing-user-id');

      expect(result, isTrue);
      expect(readState(container, 'story-1').participants, <StoryParticipant>[
        ownerParticipant,
      ]);
    });

    test('shouldExposeRemovingTargetWhilePendingAndIgnoreDuplicate', () async {
      final removeCompleter = Completer<void>();
      final repository = FakeStoryParticipantRepository()
        ..removeCompleter = removeCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      final notifier = container.read(
        storyParticipantsProvider('story-1').notifier,
      );

      final firstRemove = notifier.removeParticipant('viewer-user-id');
      await pumpEventQueue();
      final secondResult = await notifier.removeParticipant('editor-user-id');

      expect(secondResult, isFalse);
      expect(repository.removeCalls, 1);
      expect(
        readState(container, 'story-1').removingParticipantUserId,
        'viewer-user-id',
      );

      removeCompleter.complete();
      expect(await firstRemove, isTrue);
    });

    test('shouldExposeKnownRemoveFailuresAndPreserveParticipants', () async {
      final failures = <ParticipantFailure>[
        const ParticipantOwnerCannotBeRemoved(),
        const ParticipantCannotRemoveSelf(),
        const ParticipantNotFound(),
        const ParticipantUnauthorized(),
        const ParticipantNetworkUnavailable(),
        const ParticipantServerFailure(),
      ];

      for (final failure in failures) {
        final repository = FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            ownerParticipant,
            viewerParticipant,
          ]
          ..removeFailure = ParticipantApplicationException(failure);
        final container = createContainer(repository);
        addTearDown(container.dispose);
        await container.read(storyParticipantsProvider('story-1').future);

        final result = await container
            .read(storyParticipantsProvider('story-1').notifier)
            .removeParticipant('viewer-user-id');

        expect(result, isFalse);
        expect(readState(container, 'story-1').participants, <StoryParticipant>[
          ownerParticipant,
          viewerParticipant,
        ]);
        expect(readState(container, 'story-1').removeFailure, failure);
        expect(readState(container, 'story-1').removingParticipantUserId, isNull);
      }
    });

    test('shouldConvertBlankTargetToValidationFailureWithoutRepositoryCall',
        () async {
      final repository = FakeStoryParticipantRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final result = await container
          .read(storyParticipantsProvider('story-1').notifier)
          .removeParticipant('   ');

      expect(result, isFalse);
      expect(repository.removeCalls, 0);
      expect(
        readState(container, 'story-1').removeFailure,
        const ParticipantValidationFailure(),
      );
    });

    test('shouldExposeUnexpectedRemoveFailureAsAsyncError', () async {
      final repository = FakeStoryParticipantRepository()
        ..removeFailure = const UnexpectedParticipantException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final result = await container
          .read(storyParticipantsProvider('story-1').notifier)
          .removeParticipant('viewer-user-id');

      expect(result, isFalse);
      expect(
        container.read(storyParticipantsProvider('story-1')),
        isA<AsyncError<ParticipantsState>>(),
      );
    });
  });

  group('ParticipantsNotifier concurrency', () {
    test('shouldIgnoreLeaveAndRemoveWhileRefreshActive', () async {
      final refreshCompleter = Completer<List<StoryParticipant>>();
      final repository = FakeStoryParticipantRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);
      repository.getCompleter = refreshCompleter;

      final notifier = container.read(
        storyParticipantsProvider('story-1').notifier,
      );
      final refresh = notifier.refreshParticipants();
      await pumpEventQueue();
      final leaveResult = await notifier.leaveStory();
      final removeResult = await notifier.removeParticipant('viewer-user-id');

      expect(leaveResult, isFalse);
      expect(removeResult, isFalse);
      expect(repository.leaveCalls, 0);
      expect(repository.removeCalls, 0);

      refreshCompleter.complete(<StoryParticipant>[viewerParticipant]);
      await refresh;
      expect(readState(container, 'story-1').participants, <StoryParticipant>[
        viewerParticipant,
      ]);
    });

    test('shouldIgnoreRefreshAndRemoveWhileLeaveActive', () async {
      final leaveCompleter = Completer<void>();
      final repository = FakeStoryParticipantRepository()
        ..leaveCompleter = leaveCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final notifier = container.read(
        storyParticipantsProvider('story-1').notifier,
      );
      final leave = notifier.leaveStory();
      await pumpEventQueue();
      await notifier.refreshParticipants();
      final removeResult = await notifier.removeParticipant('viewer-user-id');

      expect(removeResult, isFalse);
      expect(repository.getCalls, 1);
      expect(repository.removeCalls, 0);

      leaveCompleter.complete();
      expect(await leave, isTrue);
    });

    test('shouldIgnoreRefreshAndLeaveWhileRemoveActive', () async {
      final removeCompleter = Completer<void>();
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[
          ownerParticipant,
          viewerParticipant,
        ]
        ..removeCompleter = removeCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('story-1').future);

      final notifier = container.read(
        storyParticipantsProvider('story-1').notifier,
      );
      final remove = notifier.removeParticipant('viewer-user-id');
      await pumpEventQueue();
      await notifier.refreshParticipants();
      final leaveResult = await notifier.leaveStory();

      expect(leaveResult, isFalse);
      expect(repository.getCalls, 1);
      expect(repository.leaveCalls, 0);

      removeCompleter.complete();
      expect(await remove, isTrue);
      expect(readState(container, 'story-1').participants, <StoryParticipant>[
        ownerParticipant,
      ]);
    });
  });

  group('ParticipantsNotifier provider lifecycle', () {
    test('shouldKeepIndependentStatePerStoryId', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResults.add(<StoryParticipant>[ownerParticipant])
        ..participantsResults.add(<StoryParticipant>[viewerParticipant]);
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final first = await container.read(
        storyParticipantsProvider('story-1').future,
      );
      final second = await container.read(
        storyParticipantsProvider('story-2').future,
      );

      expect(first.participants, <StoryParticipant>[ownerParticipant]);
      expect(second.participants, <StoryParticipant>[viewerParticipant]);
      expect(repository.receivedGetStoryIds, <String>['story-1', 'story-2']);
    });
  });

  group('ParticipantsNotifier security', () {
    test('shouldNotExposeParticipantDetailsThroughStateToString', () async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[privateParticipant];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyParticipantsProvider('private-story-id').future);

      final text = container
          .read(storyParticipantsProvider('private-story-id'))
          .toString();

      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('private-user-id')));
      expect(text, isNot(contains('Private Name')));
      expect(text, isNot(contains('https://cdn.memorymap.app/private.png')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('token')));
    });
  });
}

ProviderContainer createContainer(FakeStoryParticipantRepository repository) {
  return ProviderContainer(
    overrides: [
      storyParticipantRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

ParticipantsState readState(ProviderContainer container, String storyId) {
  return container.read(storyParticipantsProvider(storyId)).asData!.value;
}

final StoryParticipant ownerParticipant = StoryParticipant(
  userId: 'owner-user-id',
  displayName: 'Anna',
  avatarUrl: 'https://cdn.memorymap.app/anna.png',
  role: StoryRole.owner,
  joinedAt: DateTime.utc(2026, 8, 9, 10),
);

final StoryParticipant viewerParticipant = StoryParticipant(
  userId: 'viewer-user-id',
  displayName: 'Alex',
  avatarUrl: null,
  role: StoryRole.viewer,
  joinedAt: DateTime.utc(2026, 8, 9, 11),
);

final StoryParticipant editorParticipant = StoryParticipant(
  userId: 'editor-user-id',
  displayName: 'Mira',
  avatarUrl: 'https://cdn.memorymap.app/mira.png',
  role: StoryRole.editor,
  joinedAt: DateTime.utc(2026, 8, 9, 12),
);

final StoryParticipant privateParticipant = StoryParticipant(
  userId: 'private-user-id',
  displayName: 'Private Name',
  avatarUrl: 'https://cdn.memorymap.app/private.png',
  role: StoryRole.coOwner,
  joinedAt: DateTime.utc(2026, 8, 9, 13),
);

final class FakeStoryParticipantRepository
    implements StoryParticipantRepository {
  int getCalls = 0;
  int leaveCalls = 0;
  int removeCalls = 0;
  String? receivedGetStoryId;
  final List<String> receivedGetStoryIds = <String>[];
  LeaveStoryInput? receivedLeaveInput;
  RemoveStoryParticipantInput? receivedRemoveInput;
  List<StoryParticipant> participantsResult = <StoryParticipant>[
    ownerParticipant,
  ];
  final List<List<StoryParticipant>> participantsResults =
      <List<StoryParticipant>>[];
  final List<Object> getFailures = <Object>[];
  Object? leaveFailure;
  Object? removeFailure;
  Completer<List<StoryParticipant>>? getCompleter;
  Completer<void>? leaveCompleter;
  Completer<void>? removeCompleter;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    getCalls += 1;
    receivedGetStoryId = storyId;
    receivedGetStoryIds.add(storyId);

    final completer = getCompleter;
    if (completer != null) {
      getCompleter = null;
      return completer.future;
    }

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    if (participantsResults.isNotEmpty) {
      return participantsResults.removeAt(0);
    }

    return participantsResult;
  }

  @override
  Future<void> leaveStory(LeaveStoryInput input) async {
    leaveCalls += 1;
    receivedLeaveInput = input;

    final completer = leaveCompleter;
    if (completer != null) {
      leaveCompleter = null;
      return completer.future;
    }

    final configuredFailure = leaveFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }

  @override
  Future<void> removeParticipant(RemoveStoryParticipantInput input) async {
    removeCalls += 1;
    receivedRemoveInput = input;

    final completer = removeCompleter;
    if (completer != null) {
      removeCompleter = null;
      return completer.future;
    }

    final configuredFailure = removeFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }
}

final class UnexpectedParticipantException implements Exception {
  const UnexpectedParticipantException();
}
