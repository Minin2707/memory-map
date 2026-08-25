import 'package:memory_map/features/music/domain/story_soundtrack.dart';

abstract interface class StorySoundtrackRepository {
  Future<StorySoundtrack> getStorySoundtrack(String storyId);

  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  );

  Future<StorySoundtrack> removeStorySoundtrack(String storyId);
}
