import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/delete_memory_state.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

void main() {
  group('DeleteMemoryState', () {
    test('shouldStartIdle', () {
      const state = DeleteMemoryState();

      expect(state.isDeleting, isFalse);
      expect(state.deleteFailure, isNull);
      expect(state.hasDeleteFailure, isFalse);
    });

    test('shouldCopyWithNewValuesAndClearFailure', () {
      const state = DeleteMemoryState(
        isDeleting: true,
        deleteFailure: MemoryNetworkUnavailable(),
      );

      expect(
        state.copyWith(isDeleting: false),
        const DeleteMemoryState(
          isDeleting: false,
          deleteFailure: MemoryNetworkUnavailable(),
        ),
      );
      expect(
        state.copyWith(clearDeleteFailure: true),
        const DeleteMemoryState(isDeleting: true),
      );
    });

    test('shouldCompareByValue', () {
      const first = DeleteMemoryState(
        isDeleting: true,
        deleteFailure: MemoryRequestTimedOut(),
      );
      const second = DeleteMemoryState(
        isDeleting: true,
        deleteFailure: MemoryRequestTimedOut(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(const DeleteMemoryState()));
    });

    test('shouldUseSafeToString', () {
      const state = DeleteMemoryState(
        isDeleting: true,
        deleteFailure: MemoryDeletionUnavailable(),
      );
      final text = state.toString();

      expect(
        text,
        'DeleteMemoryState(isDeleting: true, hasDeleteFailure: true)',
      );
      expect(text, isNot(contains('memory-id')));
      expect(text, isNot(contains('story-id')));
      expect(text, isNot(contains('private')));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('HTTP')));
      expect(text, isNot(contains('token')));
    });
  });
}
