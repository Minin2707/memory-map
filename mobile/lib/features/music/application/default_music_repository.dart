import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/data/remote/music_remote_data_source.dart';
import 'package:memory_map/features/music/data/remote/music_remote_exception.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_repository.dart';
import 'package:memory_map/features/music/domain/music_track.dart';

final class DefaultMusicRepository implements MusicRepository {
  const DefaultMusicRepository({
    required MusicRemoteDataSource musicRemoteDataSource,
  }) : _musicRemoteDataSource = musicRemoteDataSource;

  final MusicRemoteDataSource _musicRemoteDataSource;

  @override
  Future<List<MusicTrack>> getAvailableTracks() async {
    try {
      return await _musicRemoteDataSource.getAvailableTracks();
    } on MusicRemoteException catch (exception) {
      throw MusicApplicationException(mapMusicFailure(exception));
    }
  }
}

MusicFailure mapMusicFailure(MusicRemoteException exception) {
  return switch (exception) {
    MusicRemoteValidationException() => const MusicValidationFailure(),
    MusicRemoteUnauthorizedException() => const MusicUnauthorized(),
    MusicRemoteUnavailableException() => const MusicUnavailable(),
    MusicRemoteNetworkException() => const MusicNetworkUnavailable(),
    MusicRemoteTimeoutException() => const MusicRequestTimedOut(),
    MusicRemoteServerException() => const MusicServerFailure(),
    MusicRemoteMalformedResponseException() => const UnknownMusicFailure(),
    MusicRemoteUnknownException() => const UnknownMusicFailure(),
  };
}
