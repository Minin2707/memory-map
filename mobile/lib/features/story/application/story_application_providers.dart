import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/default_story_repository.dart';
import 'package:memory_map/features/story/data/remote/dio_story_remote_data_source.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return DefaultStoryRepository(
    storyRemoteDataSource: ref.watch(storyRemoteDataSourceProvider),
  );
});
