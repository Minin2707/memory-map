import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/data/remote/create_story_remote_request.dart';
import 'package:memory_map/features/story/data/remote/update_story_remote_request.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

abstract interface class StoryRemoteDataSource {
  Future<Story> createStory(CreateStoryRemoteRequest request);

  Future<List<UserStory>> getStories();

  Future<UserStory> getStory(String storyId);

  Future<UserStory> updateStory(
    String storyId,
    UpdateStoryRemoteRequest request,
  );

  Future<UserStory> uploadCover(
    String storyId,
    PreparedPhotoUpload photo,
  );

  Future<UserStory> removeCover(String storyId);
}
