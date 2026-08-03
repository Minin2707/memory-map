import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';

void main() {
  group('InviteFailure', () {
    test('shouldCreateAllInviteFailureVariants', () {
      const failures = <InviteFailure>[
        InviteValidationFailure(),
        InviteUnauthorized(),
        InviteNotFound(),
        InviteNetworkUnavailable(),
        InviteRequestTimedOut(),
        InviteServerFailure(),
        UnknownInviteFailure(),
      ];

      expect(failures, hasLength(7));
    });

    test('shouldCompareSameFailureTypesAsEqual', () {
      expect(const InviteNotFound(), const InviteNotFound());
      expect(const InviteNetworkUnavailable(), const InviteNetworkUnavailable());
      expect(const UnknownInviteFailure(), const UnknownInviteFailure());
    });

    test('shouldCompareDifferentFailureTypesAsNotEqual', () {
      expect(const InviteNotFound(), isNot(const InviteUnauthorized()));
      expect(const InviteServerFailure(), isNot(const InviteRequestTimedOut()));
      expect(
        const InviteValidationFailure(),
        isNot(const UnknownInviteFailure()),
      );
    });

    test('shouldProduceStableHashCodeForSameFailureType', () {
      expect(
        const InviteNotFound().hashCode,
        const InviteNotFound().hashCode,
      );
      expect(
        const UnknownInviteFailure().hashCode,
        const UnknownInviteFailure().hashCode,
      );
    });

    test('shouldExposeOnlySafeFailureTypeInToString', () {
      const failure = InviteNotFound();

      expect(failure.toString(), 'InviteNotFound');
      expect(failure.toString(), isNot(contains('story-id')));
      expect(failure.toString(), isNot(contains('user-id')));
      expect(failure.toString(), isNot(contains('raw-token')));
      expect(failure.toString(), isNot(contains('tokenHash')));
      expect(failure.toString(), isNot(contains('Dio')));
      expect(failure.toString(), isNot(contains('HTTP')));
      expect(failure.toString(), isNot(contains('response body')));
    });
  });
}
