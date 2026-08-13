import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/playback/domain/playback_progress.dart';

void main() {
  group('PlaybackProgress', () {
    test('shouldExposePositionTotalAndFraction', () {
      final progress = PlaybackProgress(currentPosition: 2, total: 8);

      expect(progress.currentPosition, 2);
      expect(progress.total, 8);
      expect(progress.fraction, 0.25);
    });

    test('shouldExposeSafeZeroFractionForEmptyProgress', () {
      final progress = PlaybackProgress(currentPosition: 0, total: 0);

      expect(progress.fraction, 0);
    });

    test('shouldRejectInvalidProgress', () {
      expect(
        () => PlaybackProgress(currentPosition: -1, total: 1),
        throwsA(argumentErrorWithMessage('currentPosition must not be negative')),
      );
      expect(
        () => PlaybackProgress(currentPosition: 0, total: -1),
        throwsA(argumentErrorWithMessage('total must not be negative')),
      );
      expect(
        () => PlaybackProgress(currentPosition: 2, total: 1),
        throwsA(argumentErrorWithMessage('currentPosition must not exceed total')),
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = PlaybackProgress(currentPosition: 1, total: 3);
      final second = PlaybackProgress(currentPosition: 1, total: 3);
      final different = PlaybackProgress(currentPosition: 2, total: 3);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
      expect(first.toString(), contains('currentPosition: 1'));
      expect(first.toString(), contains('total: 3'));
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

