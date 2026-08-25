import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/application/default_story_soundtrack_repository.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/data/remote/music_remote_exception.dart';
import 'package:memory_map/features/music/data/remote/story_soundtrack_remote_data_source.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';

void main() {
  group('DefaultStorySoundtrackRepository', () {
    test('shouldDelegateGetSetAndRemove', () async {
      final remote = FakeStorySoundtrackRemoteDataSource();
      final repository = DefaultStorySoundtrackRepository(
        storySoundtrackRemoteDataSource: remote,
      );

      await repository.getStorySoundtrack('story-id');
      await repository.setStorySoundtrack('story-id', 'track-id');
      await repository.removeStorySoundtrack('story-id');

      expect(remote.operations, <String>[
        'get:story-id',
        'set:story-id:track-id',
        'remove:story-id',
      ]);
    });

    test('shouldUseAuthoritativeRemoteResponse', () async {
      final authoritative = StorySoundtrack(
        selectedSoundtrack: trackB,
        effectiveSoundtrack: trackB,
      );
      final remote = FakeStorySoundtrackRemoteDataSource()
        ..setResult = authoritative;
      final repository = DefaultStorySoundtrackRepository(
        storySoundtrackRemoteDataSource: remote,
      );

      final soundtrack = await repository.setStorySoundtrack(
        'story-id',
        'track-a',
      );

      expect(soundtrack, authoritative);
    });

    test('shouldMapRemoteFailureToApplicationFailure', () async {
      final repository = DefaultStorySoundtrackRepository(
        storySoundtrackRemoteDataSource: FakeStorySoundtrackRemoteDataSource()
          ..failure = const MusicRemoteUnavailableException(),
      );

      await expectLater(
        repository.getStorySoundtrack('story-id'),
        throwsA(
          isA<MusicApplicationException>().having(
            (error) => error.failure,
            'failure',
            const MusicUnavailable(),
          ),
        ),
      );
    });
  });
}

final MusicTrack trackA = MusicTrack(
  id: 'track-a',
  title: 'Autumn Leaves',
  artist: 'LofCosmos',
  durationSeconds: 270,
);

final MusicTrack trackB = MusicTrack(
  id: 'track-b',
  title: 'Walk',
  artist: 'Ikson',
  durationSeconds: 180,
);

final class FakeStorySoundtrackRemoteDataSource
    implements StorySoundtrackRemoteDataSource {
  final List<String> operations = <String>[];
  MusicRemoteException? failure;
  StorySoundtrack setResult = StorySoundtrack(
    selectedSoundtrack: trackA,
    effectiveSoundtrack: trackA,
  );

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    operations.add('get:$storyId');
    _throwIfConfigured();

    return StorySoundtrack.noMusic();
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    SetStorySoundtrackRemoteRequest request,
  ) async {
    operations.add('set:$storyId:${request.musicTrackId}');
    _throwIfConfigured();

    return setResult;
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    operations.add('remove:$storyId');
    _throwIfConfigured();

    return StorySoundtrack.noMusic();
  }

  void _throwIfConfigured() {
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }
}
