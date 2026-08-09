import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

void main() {
  group('MemoryFailure', () {
    test('shouldCreateAllMemoryFailureVariants', () {
      const failures = <MemoryFailure>[
        MemoryValidationFailure(),
        MemoryUnauthorized(),
        MemoryStoryUnavailable(),
        MemoryNotFound(),
        MemoryCreationUnavailable(),
        MemoryUpdateUnavailable(),
        MemoryDeletionUnavailable(),
        MemoryNetworkUnavailable(),
        MemoryRequestTimedOut(),
        MemoryServerFailure(),
        UnknownMemoryFailure(),
      ];

      expect(failures, hasLength(11));
    });

    test('shouldCompareSameFailureTypesAsEqual', () {
      expect(const MemoryNotFound(), const MemoryNotFound());
      expect(
        const MemoryDeletionUnavailable(),
        const MemoryDeletionUnavailable(),
      );
      expect(const UnknownMemoryFailure(), const UnknownMemoryFailure());
    });

    test('shouldCompareDifferentFailureTypesAsNotEqual', () {
      expect(const MemoryNotFound(), isNot(const MemoryUnauthorized()));
      expect(
        const MemoryServerFailure(),
        isNot(const MemoryRequestTimedOut()),
      );
      expect(
        const MemoryValidationFailure(),
        isNot(const UnknownMemoryFailure()),
      );
    });

    test('shouldProduceStableHashCodeForSameFailureType', () {
      expect(
        const MemoryNotFound().hashCode,
        const MemoryNotFound().hashCode,
      );
      expect(
        const UnknownMemoryFailure().hashCode,
        const UnknownMemoryFailure().hashCode,
      );
    });

    test('shouldExposeOnlySafeFailureTypeInToString', () {
      const failure = MemoryDeletionUnavailable();

      expect(failure.toString(), 'MemoryDeletionUnavailable');
      expect(failure.toString(), isNot(contains('memory-id')));
      expect(failure.toString(), isNot(contains('story-id')));
      expect(failure.toString(), isNot(contains('user-id')));
      expect(failure.toString(), isNot(contains('41.715123')));
      expect(failure.toString(), isNot(contains('SECRET')));
      expect(failure.toString(), isNot(contains('Dio')));
      expect(failure.toString(), isNot(contains('HTTP')));
      expect(failure.toString(), isNot(contains('response body')));
    });
  });
}
