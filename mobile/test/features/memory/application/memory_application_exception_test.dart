import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

void main() {
  group('MemoryApplicationException', () {
    test('shouldExposeMemoryFailure', () {
      const exception = MemoryApplicationException(MemoryNotFound());

      expect(exception.failure, const MemoryNotFound());
    });

    test('shouldAcceptAllFailureVariants', () {
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

      for (final failure in failures) {
        expect(MemoryApplicationException(failure).failure, failure);
      }
    });

    test('shouldUseSafeToString', () {
      const exception = MemoryApplicationException(MemoryNotFound());

      expect(exception.toString(), 'MemoryApplicationException');
    });

    test('shouldNotExposeIdsContentBackendDetailsOrInfrastructureDetails', () {
      const sensitiveValues = <String>[
        'story-id',
        'memory-id',
        'user-id',
        'First picnic',
        'secret description',
        'secret place',
        '55.751244',
        '37.618423',
        '2026-08-09',
        'signed-access-token',
        'Authorization',
        'DioException',
        'MemoryRemoteNotFoundException',
        'ProblemDetail',
        'HTTP',
        '404',
        '500',
      ];
      const exception = MemoryApplicationException(MemoryNotFound());

      for (final value in sensitiveValues) {
        expect(exception.toString(), isNot(contains(value)));
      }
    });
  });
}
