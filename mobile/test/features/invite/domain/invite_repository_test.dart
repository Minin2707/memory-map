import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('InviteRepository', () {
    test('shouldExposeCreateInviteContract', () async {
      final repository = FakeInviteRepository();
      final input = CreateInviteInput(storyId: 'story-id');

      final invite = await repository.createInvite(input);

      expect(repository.receivedCreateInviteInput, input);
      expect(invite, createInviteFixture());
    });

    test('shouldExposeAcceptInviteContract', () async {
      final repository = FakeInviteRepository();
      final input = AcceptInviteInput(rawToken: 'raw-token');

      final userStory = await repository.acceptInvite(input);

      expect(repository.receivedAcceptInviteInput, input);
      expect(userStory, createUserStory());
    });
  });
}

final class FakeInviteRepository implements InviteRepository {
  CreateInviteInput? receivedCreateInviteInput;
  AcceptInviteInput? receivedAcceptInviteInput;

  @override
  Future<Invite> createInvite(CreateInviteInput input) async {
    receivedCreateInviteInput = input;

    return createInviteFixture();
  }

  @override
  Future<UserStory> acceptInvite(AcceptInviteInput input) async {
    receivedAcceptInviteInput = input;

    return createUserStory();
  }
}

Invite createInviteFixture() {
  return Invite(
    inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-123'),
    expiresAt: DateTime.utc(2026, 8, 5, 10),
  );
}

UserStory createUserStory() {
  return UserStory(
    story: Story(
      id: 'story-id',
      title: 'Our Story',
      description: 'Together since 2021',
      createdAt: DateTime.utc(2026, 8, 3, 10),
      updatedAt: DateTime.utc(2026, 8, 3, 11),
    ),
    role: StoryRole.coOwner,
  );
}
