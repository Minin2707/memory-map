import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';

void main() {
  group('PlaybackCameraCommand', () {
    test('shouldCreateCommand', () {
      final command = PlaybackCameraCommand(
        revision: 3,
        memoryIndex: 2,
        target: coordinate,
        duration: const Duration(seconds: 2),
      );

      expect(command.revision, 3);
      expect(command.memoryIndex, 2);
      expect(command.target, coordinate);
      expect(command.duration, const Duration(seconds: 2));
    });

    test('shouldRejectInvalidValues', () {
      expect(
        () => PlaybackCameraCommand(
          revision: -1,
          memoryIndex: 0,
          target: coordinate,
          duration: const Duration(seconds: 2),
        ),
        throwsA(argumentErrorWithMessage('revision must not be negative')),
      );
      expect(
        () => PlaybackCameraCommand(
          revision: 1,
          memoryIndex: -1,
          target: coordinate,
          duration: const Duration(seconds: 2),
        ),
        throwsA(argumentErrorWithMessage('memoryIndex must not be negative')),
      );
      expect(
        () => PlaybackCameraCommand(
          revision: 1,
          memoryIndex: 0,
          target: coordinate,
          duration: Duration.zero,
        ),
        throwsA(argumentErrorWithMessage('duration must be positive')),
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = PlaybackCameraCommand(
        revision: 1,
        memoryIndex: 0,
        target: coordinate,
        duration: const Duration(seconds: 2),
      );
      final second = PlaybackCameraCommand(
        revision: 1,
        memoryIndex: 0,
        target: coordinate,
        duration: const Duration(seconds: 2),
      );
      final different = PlaybackCameraCommand(
        revision: 2,
        memoryIndex: 0,
        target: coordinate,
        duration: const Duration(seconds: 2),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));

      final text = first.toString();
      expect(text, contains('revision: 1'));
      expect(text, contains('memoryIndex: 0'));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
    });
  });
}

final coordinate = MapCoordinate(latitude: 41.7151, longitude: 44.8271);

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

