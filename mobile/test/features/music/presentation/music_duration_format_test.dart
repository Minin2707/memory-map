import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/presentation/music_duration_format.dart';

void main() {
  group('formatMusicDuration', () {
    test('shouldFormatMinutesAndSeconds', () {
      expect(formatMusicDuration(70), '1:10');
      expect(formatMusicDuration(133), '2:13');
      expect(formatMusicDuration(270), '4:30');
    });

    test('shouldFormatHourLongDurations', () {
      expect(formatMusicDuration(3600), '1:00:00');
      expect(formatMusicDuration(3670), '1:01:10');
    });

    test('shouldHandleNegativeValuesDefensively', () {
      expect(formatMusicDuration(-1), '0:00');
    });
  });
}
