import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/application/default_music_repository.dart';
import 'package:memory_map/features/music/application/default_story_soundtrack_repository.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/data/remote/dio_music_remote_data_source.dart';
import 'package:memory_map/features/music/data/remote/music_remote_data_source.dart';
import 'package:memory_map/features/music/data/remote/story_soundtrack_remote_data_source.dart';
import 'package:memory_map/features/music/domain/music_repository.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';

void main() {
  group('music application providers', () {
    test('shouldCreateMusicRepositoryFromRemoteProvider', () {
      final remote = FakeMusicRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          musicRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(musicRepositoryProvider);

      expect(repository, isA<MusicRepository>());
      expect(repository, isA<DefaultMusicRepository>());
      expect(remote.getAvailableTracksCalls, 0);
    });

    test('shouldCreateStorySoundtrackRepositoryFromRemoteProvider', () {
      final remote = FakeStorySoundtrackRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          storySoundtrackRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(storySoundtrackRepositoryProvider);

      expect(repository, isA<StorySoundtrackRepository>());
      expect(repository, isA<DefaultStorySoundtrackRepository>());
      expect(remote.getCalls, 0);
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

  @override
  Future<List<MusicTrack>> getAvailableTracks() async {
    getAvailableTracksCalls += 1;

    return <MusicTrack>[trackA];
  }
}

final class FakeStorySoundtrackRemoteDataSource
    implements StorySoundtrackRemoteDataSource {
  int getCalls = 0;

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    getCalls += 1;

    return StorySoundtrack.noMusic();
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    SetStorySoundtrackRemoteRequest request,
  ) async {
    return StorySoundtrack(
      selectedSoundtrack: trackA,
      effectiveSoundtrack: trackA,
    );
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    return StorySoundtrack.noMusic();
  }
}
