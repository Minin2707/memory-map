import 'package:memory_map/features/story/domain/user_story.dart';

abstract interface class UserStoryResponseDecoder {
  UserStory decode(Object? payload);
}
