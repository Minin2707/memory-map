import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/create_memory_state.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

void main() {
  group('CreateMemoryState', () {
    test('shouldStartIdle', () {
      const state = CreateMemoryState();

      expect(state.isSubmitting, isFalse);
      expect(state.failure, isNull);
      expect(state.hasFailure, isFalse);
    });

    test('shouldCopyValuesAndClearFailure', () {
      const state = CreateMemoryState(
        isSubmitting: true,
        failure: MemoryNetworkUnavailable(),
      );

      expect(
        state.copyWith(isSubmitting: false),
        const CreateMemoryState(
          isSubmitting: false,
          failure: MemoryNetworkUnavailable(),
        ),
      );
      expect(
        state.copyWith(clearFailure: true),
        const CreateMemoryState(isSubmitting: true),
      );
    });

    test('shouldCompareByValue', () {
      const first = CreateMemoryState(
        isSubmitting: true,
        failure: MemoryRequestTimedOut(),
      );
      const second = CreateMemoryState(
        isSubmitting: true,
        failure: MemoryRequestTimedOut(),
      );
      const different = CreateMemoryState(
        isSubmitting: false,
        failure: MemoryRequestTimedOut(),
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      const state = CreateMemoryState(
        isSubmitting: true,
        failure: MemoryValidationFailure(),
      );
      final value = state.toString();

      expect(
        value,
        'CreateMemoryState(isSubmitting: true, hasFailure: true)',
      );
      expect(value, isNot(contains('story-id')));
      expect(value, isNot(contains('memory-id')));
      expect(value, isNot(contains('SECRET')));
      expect(value, isNot(contains('55.751244')));
      expect(value, isNot(contains('37.618423')));
      expect(value, isNot(contains('MemoryValidationFailure')));
      expect(value, isNot(contains('Dio')));
      expect(value, isNot(contains('HTTP')));
    });
  });
}
