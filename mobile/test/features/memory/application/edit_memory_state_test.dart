import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/edit_memory_state.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

void main() {
  group('EditMemoryState', () {
    test('shouldStartIdle', () {
      const state = EditMemoryState();

      expect(state.isSaving, isFalse);
      expect(state.saveFailure, isNull);
      expect(state.hasSaveFailure, isFalse);
    });

    test('shouldCopyWithNewValuesAndClearFailure', () {
      const state = EditMemoryState(
        isSaving: true,
        saveFailure: MemoryNetworkUnavailable(),
      );

      expect(
        state.copyWith(isSaving: false),
        const EditMemoryState(
          isSaving: false,
          saveFailure: MemoryNetworkUnavailable(),
        ),
      );
      expect(
        state.copyWith(clearSaveFailure: true),
        const EditMemoryState(isSaving: true),
      );
    });

    test('shouldCompareByValue', () {
      const first = EditMemoryState(
        isSaving: true,
        saveFailure: MemoryRequestTimedOut(),
      );
      const second = EditMemoryState(
        isSaving: true,
        saveFailure: MemoryRequestTimedOut(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(const EditMemoryState()));
    });

    test('shouldUseSafeToString', () {
      const state = EditMemoryState(
        isSaving: true,
        saveFailure: MemoryUpdateUnavailable(),
      );
      final text = state.toString();

      expect(
        text,
        'EditMemoryState(isSaving: true, hasSaveFailure: true)',
      );
      expect(text, isNot(contains('memory-id')));
      expect(text, isNot(contains('story-id')));
      expect(text, isNot(contains('private')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('HTTP')));
      expect(text, isNot(contains('token')));
    });
  });
}
