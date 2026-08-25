import 'package:memory_map/features/music/application/default_music_repository.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/data/remote/music_remote_exception.dart';
import 'package:memory_map/features/music/data/remote/story_soundtrack_remote_data_source.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';

final class DefaultStorySoundtrackRepository
    implements StorySoundtrackRepository {
  const DefaultStorySoundtrackRepository({
    required StorySoundtrackRemoteDataSource storySoundtrackRemoteDataSource,
  }) : _storySoundtrackRemoteDataSource = storySoundtrackRemoteDataSource;

  final StorySoundtrackRemoteDataSource _storySoundtrackRemoteDataSource;

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    try {
      return await _storySoundtrackRemoteDataSource.getStorySoundtrack(storyId);
    } on MusicRemoteException catch (exception) {
      throw MusicApplicationException(mapMusicFailure(exception));
    }
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) async {
    try {
      return await _storySoundtrackRemoteDataSource.setStorySoundtrack(
        storyId,
        SetStorySoundtrackRemoteRequest(musicTrackId: musicTrackId),
      );
    } on MusicRemoteException catch (exception) {
      throw MusicApplicationException(mapMusicFailure(exception));
    }
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    try {
      return await _storySoundtrackRemoteDataSource.removeStorySoundtrack(
        storyId,
      );
    } on MusicRemoteException catch (exception) {
      throw MusicApplicationException(mapMusicFailure(exception));
    }
  }
}
