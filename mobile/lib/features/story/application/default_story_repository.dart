import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/data/remote/create_story_remote_request.dart';
import 'package:memory_map/features/story/data/remote/story_patch_field.dart';
import 'package:memory_map/features/story/data/remote/story_remote_data_source.dart';
import 'package:memory_map/features/story/data/remote/story_remote_exception.dart';
import 'package:memory_map/features/story/data/remote/update_story_remote_request.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_update_field.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class DefaultStoryRepository implements StoryRepository {
  const DefaultStoryRepository({
    required StoryRemoteDataSource storyRemoteDataSource,
  }) : _storyRemoteDataSource = storyRemoteDataSource;

  final StoryRemoteDataSource _storyRemoteDataSource;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    try {
      return await _storyRemoteDataSource.createStory(
        CreateStoryRemoteRequest(
          title: title,
          description: description,
        ),
      );
    } on StoryRemoteException catch (exception) {
      throw StoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<List<UserStory>> getStories() async {
    try {
      return await _storyRemoteDataSource.getStories();
    } on StoryRemoteException catch (exception) {
      throw StoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    try {
      return await _storyRemoteDataSource.getStory(storyId);
    } on StoryRemoteException catch (exception) {
      throw StoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    try {
      return await _storyRemoteDataSource.updateStory(
        input.storyId,
        UpdateStoryRemoteRequest(
          title: _toRemoteField(input.title),
          description: _toRemoteField(input.description),
        ),
      );
    } on StoryRemoteException catch (exception) {
      throw StoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  }) async {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    try {
      return await _storyRemoteDataSource.uploadCover(storyId, photo);
    } on StoryRemoteException catch (exception) {
      throw StoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<UserStory> removeStoryCover({
    required String storyId,
  }) async {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    try {
      return await _storyRemoteDataSource.removeCover(storyId);
    } on StoryRemoteException catch (exception) {
      throw StoryApplicationException(_mapFailure(exception));
    }
  }

  StoryPatchField<T> _toRemoteField<T>(StoryUpdateField<T> field) {
    if (field.isProvided) {
      return StoryPatchField<T>.provided(field.value);
    }

    return StoryPatchField<T>.notProvided();
  }

  StoryFailure _mapFailure(StoryRemoteException exception) {
    return switch (exception) {
      StoryRemoteValidationException() => const StoryValidationFailure(),
      StoryRemoteUnauthorizedException() => const StoryUnauthorized(),
      StoryRemoteNotFoundException() => const StoryNotFound(),
      StoryRemoteNetworkException() => const StoryNetworkUnavailable(),
      StoryRemoteTimeoutException() => const StoryRequestTimedOut(),
      StoryRemoteServerException() => const StoryServerFailure(),
      StoryRemoteMalformedResponseException() => const UnknownStoryFailure(),
      StoryRemoteUnknownException() => const UnknownStoryFailure(),
    };
  }
}
