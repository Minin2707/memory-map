import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';

void main() {
  group('ParticipantFailure', () {
    test('shouldCreateAllParticipantFailureVariants', () {
      const failures = <ParticipantFailure>[
        ParticipantValidationFailure(),
        ParticipantUnauthorized(),
        ParticipantNotFound(),
        ParticipantLastOwnerConflict(),
        ParticipantCannotRemoveSelf(),
        ParticipantOwnerCannotBeRemoved(),
        ParticipantNetworkUnavailable(),
        ParticipantRequestTimedOut(),
        ParticipantServerFailure(),
        UnknownParticipantFailure(),
      ];

      expect(failures, hasLength(10));
    });

    test('shouldCompareSameFailureTypesAsEqual', () {
      expect(const ParticipantNotFound(), const ParticipantNotFound());
      expect(
        const ParticipantLastOwnerConflict(),
        const ParticipantLastOwnerConflict(),
      );
      expect(
        const ParticipantCannotRemoveSelf(),
        const ParticipantCannotRemoveSelf(),
      );
    });

    test('shouldCompareDifferentFailureTypesAsNotEqual', () {
      expect(
        const ParticipantNotFound(),
        isNot(const ParticipantUnauthorized()),
      );
      expect(
        const ParticipantOwnerCannotBeRemoved(),
        isNot(const ParticipantCannotRemoveSelf()),
      );
      expect(
        const ParticipantValidationFailure(),
        isNot(const UnknownParticipantFailure()),
      );
    });

    test('shouldProduceStableHashCodeForSameFailureType', () {
      expect(
        const ParticipantNotFound().hashCode,
        const ParticipantNotFound().hashCode,
      );
      expect(
        const UnknownParticipantFailure().hashCode,
        const UnknownParticipantFailure().hashCode,
      );
    });

    test('shouldExposeOnlySafeFailureTypeInToString', () {
      const failure = ParticipantNotFound();

      expect(failure.toString(), 'ParticipantNotFound');
      expect(failure.toString(), isNot(contains('story-id')));
      expect(failure.toString(), isNot(contains('user-id')));
      expect(failure.toString(), isNot(contains('role')));
      expect(failure.toString(), isNot(contains('status')));
      expect(failure.toString(), isNot(contains('raw message')));
      expect(failure.toString(), isNot(contains('Dio')));
      expect(failure.toString(), isNot(contains('HTTP')));
      expect(failure.toString(), isNot(contains('response body')));
    });
  });
}
