import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/application/participants_state.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('ParticipantsState', () {
    test('shouldCreateLoadedStateWithParticipants', () {
      final state = ParticipantsState(
        participants: <StoryParticipant>[ownerParticipant, viewerParticipant],
      );

      expect(state.participants, <StoryParticipant>[
        ownerParticipant,
        viewerParticipant,
      ]);
      expect(state.isLoaded, isTrue);
      expect(state.hasLoadFailure, isFalse);
      expect(state.isRemoving, isFalse);
      expect(state.hasActiveOperation, isFalse);
    });

    test('shouldRepresentEmptyLoadedState', () {
      final state = ParticipantsState();

      expect(state.participants, isEmpty);
      expect(state.isLoaded, isTrue);
      expect(state.loadFailure, isNull);
    });

    test('shouldDefensivelyCopyAndExposeUnmodifiableParticipants', () {
      final source = <StoryParticipant>[ownerParticipant];
      final state = ParticipantsState(participants: source);

      source.add(viewerParticipant);

      expect(state.participants, <StoryParticipant>[ownerParticipant]);
      expect(
        () => state.participants.add(viewerParticipant),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('shouldExposeOperationFlagsAndFailures', () {
      final state = ParticipantsState(
        participants: <StoryParticipant>[ownerParticipant],
        isRefreshing: true,
        isLeaving: true,
        removingParticipantUserId: 'viewer-user-id',
        loadFailure: const ParticipantNotFound(),
        refreshFailure: const ParticipantNetworkUnavailable(),
        leaveFailure: const ParticipantLastOwnerConflict(),
        removeFailure: const ParticipantCannotRemoveSelf(),
      );

      expect(state.isRefreshing, isTrue);
      expect(state.isLeaving, isTrue);
      expect(state.isRemoving, isTrue);
      expect(state.hasActiveOperation, isTrue);
      expect(state.hasLoadFailure, isTrue);
      expect(state.isLoaded, isFalse);
      expect(state.refreshFailure, const ParticipantNetworkUnavailable());
      expect(state.leaveFailure, const ParticipantLastOwnerConflict());
      expect(state.removeFailure, const ParticipantCannotRemoveSelf());
    });

    test('shouldCopyWithNewValues', () {
      final state = ParticipantsState(
        participants: <StoryParticipant>[ownerParticipant],
      );

      final updated = state.copyWith(
        participants: <StoryParticipant>[viewerParticipant],
        isRefreshing: true,
        isLeaving: true,
        removingParticipantUserId: 'viewer-user-id',
        loadFailure: const ParticipantNotFound(),
        refreshFailure: const ParticipantRequestTimedOut(),
        leaveFailure: const ParticipantLastOwnerConflict(),
        removeFailure: const ParticipantOwnerCannotBeRemoved(),
      );

      expect(updated.participants, <StoryParticipant>[viewerParticipant]);
      expect(updated.isRefreshing, isTrue);
      expect(updated.isLeaving, isTrue);
      expect(updated.removingParticipantUserId, 'viewer-user-id');
      expect(updated.loadFailure, const ParticipantNotFound());
      expect(updated.refreshFailure, const ParticipantRequestTimedOut());
      expect(updated.leaveFailure, const ParticipantLastOwnerConflict());
      expect(updated.removeFailure, const ParticipantOwnerCannotBeRemoved());
    });

    test('shouldClearNullableFieldsExplicitly', () {
      final state = ParticipantsState(
        removingParticipantUserId: 'viewer-user-id',
        loadFailure: const ParticipantNotFound(),
        refreshFailure: const ParticipantNetworkUnavailable(),
        leaveFailure: const ParticipantLastOwnerConflict(),
        removeFailure: const ParticipantCannotRemoveSelf(),
      );

      final updated = state.copyWith(
        clearRemovingParticipantUserId: true,
        clearLoadFailure: true,
        clearRefreshFailure: true,
        clearLeaveFailure: true,
        clearRemoveFailure: true,
      );

      expect(updated.removingParticipantUserId, isNull);
      expect(updated.loadFailure, isNull);
      expect(updated.refreshFailure, isNull);
      expect(updated.leaveFailure, isNull);
      expect(updated.removeFailure, isNull);
      expect(updated.isLoaded, isTrue);
    });

    test('shouldExposeEqualityAndHashCode', () {
      final first = ParticipantsState(
        participants: <StoryParticipant>[ownerParticipant],
        isRefreshing: true,
        refreshFailure: const ParticipantNetworkUnavailable(),
      );
      final second = ParticipantsState(
        participants: <StoryParticipant>[ownerParticipant],
        isRefreshing: true,
        refreshFailure: const ParticipantNetworkUnavailable(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final state = ParticipantsState(
        participants: <StoryParticipant>[privateParticipant],
        removingParticipantUserId: 'private-user-id',
        loadFailure: const ParticipantNotFound(),
        refreshFailure: const ParticipantNetworkUnavailable(),
        leaveFailure: const ParticipantLastOwnerConflict(),
        removeFailure: const ParticipantOwnerCannotBeRemoved(),
      );

      final text = state.toString();

      expect(text, contains('participantCount: 1'));
      expect(text, contains('hasLoadFailure: true'));
      expect(text, isNot(contains('private-user-id')));
      expect(text, isNot(contains('Private Name')));
      expect(text, isNot(contains('https://cdn.memorymap.app/private.png')));
      expect(text, isNot(contains('story-id')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('HTTP')));
      expect(text, isNot(contains('ProblemDetail')));
      expect(text, isNot(contains('A story owner cannot be removed')));
    });
  });
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

final StoryParticipant privateParticipant = StoryParticipant(
  userId: 'private-user-id',
  displayName: 'Private Name',
  avatarUrl: 'https://cdn.memorymap.app/private.png',
  role: StoryRole.coOwner,
  joinedAt: DateTime.utc(2026, 8, 9, 12),
);
