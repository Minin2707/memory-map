import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/data/dto/music_track_dto.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';

void main() {
  group('MusicTrackDto', () {
    test('shouldParseValidJson', () {
      final dto = MusicTrackDto.fromJson(validTrackJson());

      expect(dto.id, 'track-id');
      expect(dto.title, 'Autumn Leaves');
      expect(dto.artist, 'LofCosmos');
      expect(dto.durationSeconds, 270);
    });

    test('shouldMapToDomain', () {
      expect(
        MusicTrackDto.fromJson(validTrackJson()).toDomain(),
        MusicTrack(
          id: 'track-id',
          title: 'Autumn Leaves',
          artist: 'LofCosmos',
          durationSeconds: 270,
        ),
      );
    });

    test('shouldRejectMalformedTrack', () {
      expectMalformed(() => MusicTrackDto.fromJson(<String, Object?>{}));
      expectMalformed(
        () => MusicTrackDto.fromJson(
          <String, Object?>{
            ...validTrackJson(),
            'durationSeconds': '270',
          },
        ),
      );
      expectMalformed(
        () => MusicTrackDto.fromJson(
          <String, Object?>{
            ...validTrackJson(),
            'title': '   ',
          },
        ),
      );
    });

    test('shouldIgnoreUnknownFields', () {
      final track = MusicTrackDto.fromJson(
        <String, Object?>{
          ...validTrackJson(),
          'status': 'DISABLED',
          'storageKey': 'private/storage/key',
        },
      ).toDomain();

      expect(track.id, 'track-id');
    });

    test('shouldCompareByValueAndExposeSafeToString', () {
      final dto = MusicTrackDto.fromJson(validTrackJson());

      expect(dto, MusicTrackDto.fromJson(validTrackJson()));
      expect(dto.toString(), 'MusicTrackDto');
      expect(dto.toString(), isNot(contains('private/storage/key')));
    });
  });

  group('StorySoundtrackDto', () {
    test('shouldParseNoMusic', () {
      final soundtrack = StorySoundtrackDto.fromJson(
        <String, Object?>{
          'selectedSoundtrack': null,
          'effectiveSoundtrack': null,
        },
      ).toDomain();

      expect(soundtrack, StorySoundtrack.noMusic());
      expect(soundtrack.isNoMusic, isTrue);
    });

    test('shouldParseSelectedAndEffective', () {
      final soundtrack = StorySoundtrackDto.fromJson(
        <String, Object?>{
          'selectedSoundtrack': validTrackJson(),
          'effectiveSoundtrack': validTrackJson(),
        },
      ).toDomain();

      expect(soundtrack.selectedSoundtrack, track());
      expect(soundtrack.effectiveSoundtrack, track());
      expect(soundtrack.isEffective, isTrue);
    });

    test('shouldParseSelectedUnavailable', () {
      final soundtrack = StorySoundtrackDto.fromJson(
        <String, Object?>{
          'selectedSoundtrack': validTrackJson(),
          'effectiveSoundtrack': null,
        },
      ).toDomain();

      expect(soundtrack.selectedSoundtrack, track());
      expect(soundtrack.effectiveSoundtrack, isNull);
      expect(soundtrack.isSelectedUnavailable, isTrue);
    });

    test('shouldRejectMalformedSoundtrack', () {
      expectMalformed(() => StorySoundtrackDto.fromJson(<Object?>[]));
      expectMalformed(() => StorySoundtrackDto.fromJson(<String, Object?>{}));
      expectMalformed(
        () => StorySoundtrackDto.fromJson(
          <String, Object?>{
            'selectedSoundtrack': null,
            'effectiveSoundtrack': validTrackJson(),
          },
        ),
      );
      expectMalformed(
        () => StorySoundtrackDto.fromJson(
          <String, Object?>{
            'selectedSoundtrack': <String, Object?>{},
            'effectiveSoundtrack': null,
          },
        ),
      );
    });

    test('shouldCompareByValueAndExposeSafeToString', () {
      final dto = StorySoundtrackDto.fromJson(
        <String, Object?>{
          'selectedSoundtrack': validTrackJson(),
          'effectiveSoundtrack': null,
        },
      );

      expect(
        dto,
        StorySoundtrackDto.fromJson(
          <String, Object?>{
            'selectedSoundtrack': validTrackJson(),
            'effectiveSoundtrack': null,
          },
        ),
      );
      expect(dto.toString(), 'StorySoundtrackDto');
      expect(dto.toString(), isNot(contains('track-id')));
    });
  });
}

void expectMalformed(Object? Function() action) {
  expect(action, throwsA(isA<FormatException>()));
}

Map<String, Object?> validTrackJson() {
  return <String, Object?>{
    'id': 'track-id',
    'title': 'Autumn Leaves',
    'artist': 'LofCosmos',
    'durationSeconds': 270,
  };
}

MusicTrack track() {
  return MusicTrack(
    id: 'track-id',
    title: 'Autumn Leaves',
    artist: 'LofCosmos',
    durationSeconds: 270,
  );
}
