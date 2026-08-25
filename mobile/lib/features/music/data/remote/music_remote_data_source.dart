import 'package:memory_map/features/music/domain/music_track.dart';

abstract interface class MusicRemoteDataSource {
  Future<List<MusicTrack>> getAvailableTracks();
}
