import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/data/remote/create_story_remote_request.dart';
import 'package:memory_map/features/story/data/remote/dio_story_remote_data_source.dart';
import 'package:memory_map/features/story/data/remote/story_remote_data_source.dart';
import 'package:memory_map/features/story/data/remote/update_story_remote_request.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('storyRepositoryProvider', () {
    test('shouldCreateStoryRepositoryFromRemoteDataSourceProvider', () {
      final remote = FakeStoryRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          storyRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(storyRepositoryProvider);

      expect(repository, isA<StoryRepository>());
      expect(remote.totalCalls, 0);
    });
  });
}

final class FakeStoryRemoteDataSource implements StoryRemoteDataSource {
  int totalCalls = 0;

  @override
  Future<Story> createStory(CreateStoryRemoteRequest request) {
    totalCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() {
    totalCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> getStory(String storyId) {
    totalCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> updateStory(
    String storyId,
    UpdateStoryRemoteRequest request,
  ) {
    totalCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> uploadCover(
    String storyId,
    PreparedPhotoUpload photo,
  ) {
    totalCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> removeCover(String storyId) {
    totalCalls += 1;
    throw UnimplementedError();
  }
}
