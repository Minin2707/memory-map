import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

abstract interface class StoryRepository {
  Future<Story> createStory({
    required String title,
    String? description,
  });

  Future<List<UserStory>> getStories();

  Future<UserStory> getStory(String storyId);

  Future<UserStory> updateStory(UpdateStoryInput input);

  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  });

  Future<UserStory> removeStoryCover({
    required String storyId,
  });
}
