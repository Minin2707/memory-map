import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';

void main() {
  group('InviteApplicationException', () {
    test('shouldExposeInviteFailure', () {
      const exception = InviteApplicationException(InviteNotFound());

      expect(exception.failure, const InviteNotFound());
    });

    test('shouldAcceptAllFailureVariants', () {
      const failures = <InviteFailure>[
        InviteValidationFailure(),
        InviteUnauthorized(),
        InviteNotFound(),
        InviteNetworkUnavailable(),
        InviteRequestTimedOut(),
        InviteServerFailure(),
        UnknownInviteFailure(),
      ];

      for (final failure in failures) {
        expect(InviteApplicationException(failure).failure, failure);
      }
    });

    test('shouldUseSafeToString', () {
      const exception = InviteApplicationException(InviteNotFound());

      expect(exception.toString(), 'InviteApplicationException');
    });

    test('shouldNotExposeTokenLinkStoryIdOrInfrastructureDetails', () {
      const sensitiveValues = <String>[
        'story-id',
        'user-id',
        'raw-invite-token',
        'share-token-123',
        'https://app.memorymap.app/invite/share-token-123',
        'Authorization',
        'DioException',
        'InviteRemoteNotFoundException',
        'response body',
        'ProblemDetail',
        'HTTP',
        '404',
      ];
      const exception = InviteApplicationException(InviteNotFound());

      for (final value in sensitiveValues) {
        expect(exception.toString(), isNot(contains(value)));
      }
    });
  });
}
