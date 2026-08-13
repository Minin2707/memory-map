import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/playback/domain/playback_policy.dart';

void main() {
  group('PlaybackPolicy', () {
    test('shouldExposeMvpDurations', () {
      const policy = PlaybackPolicy();

      expect(policy.presentationDuration, const Duration(seconds: 5));
      expect(policy.cameraDuration, const Duration(seconds: 2));
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      const first = PlaybackPolicy();
      const second = PlaybackPolicy();
      const different = PlaybackPolicy(
        presentationDuration: Duration(seconds: 6),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
      expect(first.toString(), contains('0:00:05.000000'));
      expect(first.toString(), contains('0:00:02.000000'));
    });
  });
}

