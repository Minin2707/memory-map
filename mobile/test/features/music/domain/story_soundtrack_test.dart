import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';

void main() {
  group('StorySoundtrack', () {
    test('shouldRepresentNoMusic', () {
      final soundtrack = StorySoundtrack.noMusic();

      expect(soundtrack.selectedSoundtrack, isNull);
      expect(soundtrack.effectiveSoundtrack, isNull);
      expect(soundtrack.hasSelection, isFalse);
      expect(soundtrack.isNoMusic, isTrue);
      expect(soundtrack.isEffective, isFalse);
      expect(soundtrack.isSelectedUnavailable, isFalse);
    });

    test('shouldRepresentAvailableSelectedSoundtrack', () {
      final selected = musicTrack();
      final soundtrack = StorySoundtrack(
        selectedSoundtrack: selected,
        effectiveSoundtrack: selected,
      );

      expect(soundtrack.hasSelection, isTrue);
      expect(soundtrack.isNoMusic, isFalse);
      expect(soundtrack.isEffective, isTrue);
      expect(soundtrack.isSelectedUnavailable, isFalse);
    });

    test('shouldRepresentSelectedUnavailableSoundtrack', () {
      final selected = musicTrack();
      final soundtrack = StorySoundtrack(selectedSoundtrack: selected);

      expect(soundtrack.selectedSoundtrack, selected);
      expect(soundtrack.effectiveSoundtrack, isNull);
      expect(soundtrack.hasSelection, isTrue);
      expect(soundtrack.isNoMusic, isFalse);
      expect(soundtrack.isEffective, isFalse);
      expect(soundtrack.isSelectedUnavailable, isTrue);
    });

    test('shouldRejectEffectiveWithoutSelected', () {
      expect(
        () => StorySoundtrack(effectiveSoundtrack: musicTrack()),
        throwsA(
          argumentErrorWithMessage(
            'effectiveSoundtrack requires selectedSoundtrack',
          ),
        ),
      );
    });

    test('shouldCompareByValue', () {
      expect(
        StorySoundtrack(selectedSoundtrack: musicTrack()),
        StorySoundtrack(selectedSoundtrack: musicTrack()),
      );
    });
  });
}

MusicTrack musicTrack({
  String id = 'track-id',
  String title = 'Autumn Leaves',
  String artist = 'LofCosmos',
  int durationSeconds = 270,
}) {
  return MusicTrack(
    id: id,
    title: title,
    artist: artist,
    durationSeconds: durationSeconds,
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
