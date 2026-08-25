import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/application/default_music_repository.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/data/remote/music_remote_data_source.dart';
import 'package:memory_map/features/music/data/remote/music_remote_exception.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_track.dart';

void main() {
  group('DefaultMusicRepository', () {
    test('shouldDelegateCatalogLoadToRemoteDataSource', () async {
      final remote = FakeMusicRemoteDataSource();
      final repository = DefaultMusicRepository(
        musicRemoteDataSource: remote,
      );

      final tracks = await repository.getAvailableTracks();

      expect(tracks, <MusicTrack>[trackA]);
      expect(remote.getAvailableTracksCalls, 1);
    });

    test('shouldMapRemoteFailureToApplicationFailure', () async {
      final repository = DefaultMusicRepository(
        musicRemoteDataSource: FakeMusicRemoteDataSource()
          ..failure = const MusicRemoteTimeoutException(),
      );

      await expectLater(
        repository.getAvailableTracks(),
        throwsA(
          isA<MusicApplicationException>().having(
            (error) => error.failure,
            'failure',
            const MusicRequestTimedOut(),
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

final class FakeMusicRemoteDataSource implements MusicRemoteDataSource {
  int getAvailableTracksCalls = 0;
  MusicRemoteException? failure;

  @override
  Future<List<MusicTrack>> getAvailableTracks() async {
    getAvailableTracksCalls += 1;

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return <MusicTrack>[trackA];
  }
}
