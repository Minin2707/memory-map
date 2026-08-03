import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

abstract interface class InviteRepository {
  Future<Invite> createInvite(CreateInviteInput input);

  Future<UserStory> acceptInvite(AcceptInviteInput input);
}
