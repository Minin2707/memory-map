import 'package:memory_map/features/music/domain/story_soundtrack.dart';

abstract interface class StorySoundtrackRemoteDataSource {
  Future<StorySoundtrack> getStorySoundtrack(String storyId);

  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    SetStorySoundtrackRemoteRequest request,
  );

  Future<StorySoundtrack> removeStorySoundtrack(String storyId);
}

final class SetStorySoundtrackRemoteRequest {
  const SetStorySoundtrackRemoteRequest({
    required this.musicTrackId,
  });

  final String musicTrackId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'musicTrackId': musicTrackId,
    };
  }
}
