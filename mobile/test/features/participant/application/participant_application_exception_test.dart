import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';

void main() {
  group('ParticipantApplicationException', () {
    test('shouldExposeParticipantFailure', () {
      const exception = ParticipantApplicationException(ParticipantNotFound());

      expect(exception.failure, const ParticipantNotFound());
    });

    test('shouldAcceptAllFailureVariants', () {
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

      for (final failure in failures) {
        expect(ParticipantApplicationException(failure).failure, failure);
      }
    });

    test('shouldUseSafeToString', () {
      const exception = ParticipantApplicationException(ParticipantNotFound());

      expect(exception.toString(), 'ParticipantApplicationException');
    });

    test('shouldNotExposeIdsBackendDetailsOrInfrastructureDetails', () {
      const sensitiveValues = <String>[
        'story-id',
        'participant-user-id',
        'user-id',
        'raw-invite-token',
        'signed-access-token',
        'Authorization',
        'DioException',
        'ParticipantRemoteNotFoundException',
        'ProblemDetail',
        'Use the leave story operation to remove yourself',
        'A story owner cannot be removed',
        'HTTP',
        '404',
        '409',
      ];
      const exception = ParticipantApplicationException(ParticipantNotFound());

      for (final value in sensitiveValues) {
        expect(exception.toString(), isNot(contains(value)));
      }
    });
  });
}
