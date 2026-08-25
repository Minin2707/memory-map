import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/domain/music_track.dart';

void main() {
  group('MusicTrack', () {
    test('shouldCreateMusicTrack', () {
      final track = musicTrack();

      expect(track.id, 'track-id');
      expect(track.title, 'Autumn Leaves');
      expect(track.artist, 'LofCosmos');
      expect(track.durationSeconds, 270);
    });

    test('shouldRejectBlankFields', () {
      expect(
        () => musicTrack(id: '   '),
        throwsA(argumentErrorWithMessage('id must not be blank')),
      );
      expect(
        () => musicTrack(title: '   '),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
      expect(
        () => musicTrack(artist: '   '),
        throwsA(argumentErrorWithMessage('artist must not be blank')),
      );
    });

    test('shouldRejectNegativeDuration', () {
      expect(
        () => musicTrack(durationSeconds: -1),
        throwsA(
          argumentErrorWithMessage(
            'durationSeconds must not be negative',
          ),
        ),
      );
    });

    test('shouldCompareByValue', () {
      expect(musicTrack(), musicTrack());
      expect(
        musicTrack(),
        isNot(musicTrack(id: 'other-track-id')),
      );
    });

    test('shouldExposeSafeToString', () {
      final track = musicTrack(
        id: 'private-track-id',
        title: 'Private title',
        artist: 'Private artist',
      );

      expect(track.toString(), 'MusicTrack(durationSeconds: 270)');
      expect(track.toString(), isNot(contains('private-track-id')));
      expect(track.toString(), isNot(contains('Private title')));
      expect(track.toString(), isNot(contains('Private artist')));
      expect(track.toString(), isNot(contains('storageKey')));
      expect(track.toString(), isNot(contains('token')));
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
