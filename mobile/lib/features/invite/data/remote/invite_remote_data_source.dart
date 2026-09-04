import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

abstract interface class InviteRemoteDataSource {
  Future<Invite> createInvite(String storyId, StoryRole targetRole);

  Future<UserStory> acceptInvite(String rawToken);
}
