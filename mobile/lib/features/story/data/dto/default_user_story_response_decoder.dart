import 'package:memory_map/features/story/application/user_story_response_decoder.dart';
import 'package:memory_map/features/story/data/dto/user_story_dto.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class DefaultUserStoryResponseDecoder
    implements UserStoryResponseDecoder {
  const DefaultUserStoryResponseDecoder();

  @override
  UserStory decode(Object? payload) {
    return UserStoryDto.fromJson(payload).toDomain();
  }
}
