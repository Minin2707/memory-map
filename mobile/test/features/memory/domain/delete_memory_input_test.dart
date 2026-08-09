import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';

void main() {
  group('DeleteMemoryInput', () {
    test('shouldCreateInput', () {
      final input = DeleteMemoryInput(memoryId: 'memory-id');

      expect(input.memoryId, 'memory-id');
    });

    test('shouldRejectBlankMemoryId', () {
      expect(
        () => DeleteMemoryInput(memoryId: ''),
        throwsA(argumentErrorWithMessage('memoryId must not be blank')),
      );
      expect(
        () => DeleteMemoryInput(memoryId: '   '),
        throwsA(argumentErrorWithMessage('memoryId must not be blank')),
      );
    });

    test('shouldNotNormalizeMemoryId', () {
      final input = DeleteMemoryInput(memoryId: ' memory-id ');

      expect(input.memoryId, ' memory-id ');
    });

    test('shouldCompareInputsByValue', () {
      final first = DeleteMemoryInput(memoryId: 'memory-id');
      final second = DeleteMemoryInput(memoryId: 'memory-id');
      final different = DeleteMemoryInput(memoryId: 'another-memory-id');

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final input = DeleteMemoryInput(memoryId: 'memory-id-secret');

      expect(input.toString(), 'DeleteMemoryInput');
      expect(input.toString(), isNot(contains('memory-id-secret')));
      expect(input.toString(), isNot(contains('story-id')));
      expect(input.toString(), isNot(contains('user-id')));
      expect(input.toString(), isNot(contains('token')));
    });
  });
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
