import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/music/application/default_music_repository.dart';
import 'package:memory_map/features/music/application/default_story_soundtrack_repository.dart';
import 'package:memory_map/features/music/data/remote/dio_music_remote_data_source.dart';
import 'package:memory_map/features/music/domain/music_repository.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return DefaultMusicRepository(
    musicRemoteDataSource: ref.watch(musicRemoteDataSourceProvider),
  );
});

final storySoundtrackRepositoryProvider =
    Provider<StorySoundtrackRepository>((ref) {
  return DefaultStorySoundtrackRepository(
    storySoundtrackRemoteDataSource: ref.watch(
      storySoundtrackRemoteDataSourceProvider,
    ),
  );
});
