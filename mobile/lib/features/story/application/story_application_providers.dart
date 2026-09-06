import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/default_story_repository.dart';
import 'package:memory_map/features/story/application/user_story_response_decoder.dart';
import 'package:memory_map/features/story/data/dto/default_user_story_response_decoder.dart';
import 'package:memory_map/features/story/data/remote/dio_story_remote_data_source.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';

final userStoryResponseDecoderProvider = Provider<UserStoryResponseDecoder>(
  (ref) => const DefaultUserStoryResponseDecoder(),
);

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return DefaultStoryRepository(
    storyRemoteDataSource: ref.watch(storyRemoteDataSourceProvider),
  );
});
