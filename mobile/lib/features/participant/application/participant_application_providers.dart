import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/participant/application/default_story_participant_repository.dart';
import 'package:memory_map/features/participant/data/remote/dio_participant_remote_data_source.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';

final storyParticipantRepositoryProvider =
    Provider<StoryParticipantRepository>((ref) {
  return DefaultStoryParticipantRepository(
    participantRemoteDataSource: ref.watch(participantRemoteDataSourceProvider),
  );
});
