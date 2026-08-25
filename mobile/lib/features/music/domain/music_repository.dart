import 'package:memory_map/features/music/domain/music_track.dart';

abstract interface class MusicRepository {
  Future<List<MusicTrack>> getAvailableTracks();
}
